defmodule Kubereq.Websocket.Adapter do
  @moduledoc false

  use GenServer, restart: :transient

  alias Kubereq.Websocket.Response

  require Mint.HTTP

  @typep start_args ::
           {URI.t(), list(), {Process.dest(), reference()} | Process.dest(),
            conn_opts :: Keyword.t(), registry_key :: reference()}

  @type incoming_frame() :: {:binary, binary} | {:close, any, any}
  @type incoming_message() ::
          {:close, integer(), binary()}
          | {:error, binary}
          | {:stderr, binary}
          | {:stdout, binary}
          | {:binary, binary}

  @type outgoing_frame() ::
          {:close, integer(), binary()}
          | :close
          | {:binary, binary()}
          | {:text, binary()}
  @type outgoing_message() ::
          {:binary, binary()}
          | :close
          | {:close, any, any}
          | :exit
          | {:stdin, binary()}

  defstruct [:mint, :websocket, :ref, :into]

  @spec run(Req.Request.t()) ::
          {Req.Request.t(), Req.Response.t()} | {Req.Request.t(), Mint.WebSocket.error()}
  def run(%{into: _stream_to} = req) do
    conn_opts =
      req.options.connect_options
      |> Keyword.put(:mode, :passive)
      |> Keyword.put_new(:protocols, [:http1])

    headers =
      for {name, values} <- req.headers,
          value <- values do
        {name, value}
      end

    registry_key = make_ref()

    start_child_resp =
      DynamicSupervisor.start_child(
        __MODULE__,
        {__MODULE__, {req.url, headers, req.into, conn_opts, registry_key}}
      )

    case start_child_resp do
      {:ok, _pid} ->
        resp =
          Req.Response.new(
            status: 101,
            headers: [],
            trailers: [],
            body: %Response{registry_key: registry_key}
          )

        {req, resp}

      {:error, error} when is_exception(error) ->
        {req, error}

      other ->
        {req,
         %RuntimeError{
           message: "Failed to start the Websocket. start_child() returned #{inspect(other)}."
         }}
    end
  end

  def run(req) do
    {req,
     %ArgumentError{
       message:
         ":connect operation requires setting the `:into` operation on the req request to a `{pid, ref}` tuple."
     }}
  end

  @spec start_link(start_args()) :: GenServer.on_start()
  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @impl GenServer
  def init({url, headers, into, conn_opts, registry_key}) do
    Registry.register(Kubereq.Websocket.Adapter.Registry, registry_key, [])

    with {:ok, mint} <-
           Mint.HTTP.connect(
             http_scheme(url.scheme),
             url.host,
             url.port,
             conn_opts
           ),
         {:ok, mint, ref} <-
           Mint.WebSocket.upgrade(
             ws_scheme(url.scheme),
             mint,
             "#{url.path}?#{url.query}",
             headers
           ),
         {:ok, mint, upgrade_response} <- receive_upgrade_response(mint, ref),
         {:ok, mint, websocket} <-
           Mint.WebSocket.new(
             mint,
             ref,
             upgrade_response.status,
             upgrade_response.headers
           ) do
      {:ok, nil, {:continue, {:connect, mint, websocket, ref, into}}}
    else
      {:error, error} ->
        {:stop, error}

      {:error, _mint, error} ->
        {:stop, error}
    end
  end

  @impl GenServer
  def handle_continue({:connect, mint, websocket, ref, into}, _state) do
    case Mint.HTTP.set_mode(mint, :active) do
      {:ok, mint} ->
        # Mint.HTTP.controlling_process causes a side-effect, but it doesn't actually
        # change the conn, so we can ignore the value returned above.
        pid =
          case into do
            {pid, _} -> pid
            pid -> pid
          end

        Process.flag(:trap_exit, true)
        Process.monitor(pid)
        {:noreply, struct(__MODULE__, mint: mint, websocket: websocket, ref: ref, into: into)}

      {:error, error} ->
        {:stop, error}
    end
  end

  def handle_continue({:send, frame}, state) do
    case send_frame(frame, state.mint, state.websocket, state.ref) do
      {:ok, mint, websocket} ->
        {:noreply, %{state | mint: mint, websocket: websocket}}

      {:error, mint, websocket, error} ->
        {:stop, error, %{state | mint: mint, websocket: websocket}}

      :closed ->
        {:stop, {:shutdown, :closed}, state}
    end
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:stop, :normal, state}
  end

  def handle_info(message, state) when Mint.HTTP.is_connection_message(state.mint, message) do
    case receive_frames(message, state.mint, state.websocket, state.ref) do
      {:ok, mint, websocket, frames} ->
        new_state = %{state | mint: mint, websocket: websocket}

        Enum.reduce_while(frames, {:noreply, new_state}, fn
          {:binary, message}, acc ->
            message
            |> map_incoming_message()
            |> stream_to(state.into)

            {:cont, acc}

          {:close, 1_000, ""} = message, _acc ->
            stream_to(message, state.into)
            {:halt, {:stop, :normal, new_state}}

          {:close, code, reason} = message, _acc ->
            stream_to(message, state.into)
            {:halt, {:stop, {:remote_closed, code, reason}, new_state}}
        end)

      {:error, mint, websocket, error, frames} ->
        Enum.each(frames, fn
          {:binary, message} ->
            message
            |> map_incoming_message()
            |> stream_to(state.into)

          other ->
            stream_to(other, state.into)
        end)

        {:stop, error, %{state | mint: mint, websocket: websocket}}
    end
  end

  @impl GenServer
  def handle_call({:send, message}, _from, state) do
    case map_outgoing_frame(message) do
      {:ok, frame} -> {:reply, :ok, state, {:continue, {:send, frame}}}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    if not is_nil(state.mint) and Mint.HTTP.open?(state.mint) do
      {:ok, _websocket, data} = Mint.WebSocket.encode(state.websocket, :close)
      Mint.WebSocket.stream_request_body(state.mint, state.ref, data)
    end
  end

  @spec send_frame(outgoing_frame(), Mint.HTTP.t(), Mint.WebSocket.t(), Mint.Types.request_ref()) ::
          {:ok, Mint.HTTP.t(), Mint.WebSocket.t()}
          | :closed
          | {:error, Mint.HTTP.t(), Mint.WebSocket.t(), Mint.WebSocket.error()}
  defp send_frame(frame, mint, websocket, ref) do
    with true <- Mint.HTTP.open?(mint),
         {:ok, websocket, data} <- Mint.WebSocket.encode(websocket, frame),
         {:ok, mint} <- Mint.WebSocket.stream_request_body(mint, ref, data) do
      {:ok, mint, websocket}
    else
      false ->
        :closed

      {:error, mint_or_websocket, error} ->
        if is_struct(mint_or_websocket, Mint.WebSocket) do
          {:error, mint, mint_or_websocket, error}
        else
          {:error, mint_or_websocket, websocket, error}
        end
    end
  end

  @spec receive_frames(term(), Mint.HTTP.t(), Mint.WebSocket.t(), Mint.Types.request_ref()) ::
          {:ok, Mint.HTTP.t(), Mint.WebSocket.t(), [Mint.Types.response()]}
          | {:error, Mint.HTTP.t(), Mint.WebSocket.t(), Mint.WebSocket.error(),
             [Mint.Types.response()]}
  defp receive_frames(message, mint, websocket, ref) do
    with {:ok, mint, [{:data, ^ref, data}]} <- Mint.WebSocket.stream(mint, message),
         {:ok, websocket, frames} <- Mint.WebSocket.decode(websocket, data) do
      {:ok, mint, websocket, frames}
    else
      {:error, websocket, error, frames} -> {:error, mint, websocket, error, frames}
      {:error, mint, error} -> {:error, mint, websocket, error, []}
    end
  end

  @spec map_incoming_message(binary()) :: incoming_message()
  def map_incoming_message(<<1, message::binary>>), do: {:stdout, message}
  def map_incoming_message(<<2, message::binary>>), do: {:stderr, message}
  def map_incoming_message(<<3, message::binary>>), do: {:error, message}
  def map_incoming_message(binary), do: {:binary, binary}

  @spec map_outgoing_frame(outgoing_message()) ::
          {:ok, outgoing_frame()} | {:error, Exception.t()}
  def map_outgoing_frame({:binary, data}), do: {:ok, {:binary, data}}
  def map_outgoing_frame(:close), do: {:ok, :close}
  def map_outgoing_frame({:close, code, reason}), do: {:ok, {:close, code, reason}}
  def map_outgoing_frame(:exit), do: {:ok, :close}
  def map_outgoing_frame({:stdin, data}), do: {:ok, {:text, <<0>> <> data}}

  def map_outgoing_frame(data) do
    {:error,
     %ArgumentError{
       message: "The given message #{inspect(data)} is not supported to be sent to the Pod."
     }}
  end

  @spec http_scheme(binary()) :: atom()
  defp http_scheme("http"), do: :http
  defp http_scheme("https"), do: :https

  @spec ws_scheme(binary()) :: atom()
  defp ws_scheme("http"), do: :ws
  defp ws_scheme("https"), do: :wss

  @spec stream_to(incoming_message(), {Process.dest(), reference()} | Process.dest()) ::
          incoming_message()
  defp stream_to(message, {dest, ref}), do: send(dest, {ref, message})
  defp stream_to(message, dest), do: send(dest, message)

  @spec receive_upgrade_response(Mint.HTTP.t(), Mint.Types.request_ref()) ::
          {:ok, Mint.HTTP.t(), map()} | {:error, Mint.HTTP.t(), Mint.WebSocket.error()}
  defp receive_upgrade_response(mint, ref) do
    Enum.reduce_while(Stream.cycle([:ok]), {mint, %{}}, fn _, {mint, response} ->
      case Mint.HTTP.recv(mint, 0, 10_000) do
        {:ok, mint, parts} ->
          response =
            parts
            |> Map.new(fn
              {type, ^ref} -> {type, true}
              {type, ^ref, value} -> {type, value}
            end)
            |> Map.merge(response)

          # credo:disable-for-lines:3
          if response[:done],
            do: {:halt, {:ok, mint, response}},
            else: {:cont, {mint, response}}

        {:error, mint, error, _} ->
          {:halt, {:error, mint, error}}
      end
    end)
  end
end
