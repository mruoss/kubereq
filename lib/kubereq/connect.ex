defmodule Kubereq.Connect do
  @moduledoc false

  use GenServer

  require Logger
  require Mint.HTTP

  @callback handle_frame(frame :: Mint.WebSocket.frame(), state :: term()) ::
              {:noreply, new_state}
              | {:noreply, new_state, timeout()}
              | {:stop, reason, new_state}
            when new_state: term(), reason: term()

  @callback code_change(old_vsn, state :: term(), extra :: term()) ::
              {:ok, new_state :: term()} | {:error, reason :: term()}
            when old_vsn: term() | {:down, term()}

  @callback init(init_arg :: term()) ::
              {:ok, state :: any()} | {:stop, reason :: any()}

  @callback handle_info(msg :: :timeout | term(), state :: term()) ::
              {:noreply, new_state}
              | {:noreply, new_state,
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, reason :: term(), new_state}
            when new_state: term()

  @callback handle_call(request :: term(), GenServer.from(), state :: term()) ::
              {:reply, reply, new_state}
              | {:reply, reply, new_state,
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:noreply, new_state}
              | {:noreply, new_state,
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, reason, reply, new_state}
              | {:stop, reason, new_state}
            when reply: term(), new_state: term(), reason: term()

  @callback handle_cast(request :: term(), state :: term()) ::
              {:noreply, new_state}
              | {:noreply, new_state,
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, reason :: term(), new_state}
            when new_state: term()

  @callback handle_continue(continue_arg, state :: term()) ::
              {:noreply, new_state}
              | {:noreply, new_state, timeout() | :hibernate | {:continue, continue_arg}}
              | {:stop, reason :: term(), new_state}
            when new_state: term(), continue_arg: term()

  @callback terminate(reason, state :: term()) :: term()
            when reason: :normal | :shutdown | {:shutdown, term()} | term()

  @callback format_status(status :: :gen_server.format_status()) ::
              new_status :: :gen_server.format_status()

  @optional_callbacks code_change: 3,
                      terminate: 2,
                      handle_info: 2,
                      handle_cast: 2,
                      handle_call: 3,
                      format_status: 1,
                      handle_continue: 2,
                      init: 1

  defstruct [:mint, :websocket, :ref, :handler_module, :handler_state]

  defmacro __using__(opts) do
    quote do
      @behaviour Kubereq.Connect

      require Logger

      def child_spec(init_arg) do
        Keyword.validate!(init_arg, [:req, :state, :genserver_opts])
        {req, init_arg} = Keyword.fetch!(init_arg, :req)
        {handler_state, init_arg} = Keyword.get(init_arg, :state, %{})
        {req, genserver_opts} = Keyword.fetch!(init_arg, :genserver_opts)

        default = %{
          id: __MODULE__,
          start: {Kubereq.Connect, :start_link, [__MODULE__, req, handler_state, genserver_opts]}
        }

        Supervisor.child_spec(default, unquote(Macro.escape(opts)))
      end

      defoverridable child_spec: 1

      @impl Kubereq.Connect
      def init(state), do: {:ok, state}

      @impl Kubereq.Connect
      def terminate(reason, state), do: :ok

      @doc false
      @impl Kubereq.Connect
      def handle_info(msg, state) do
        proc =
          case Process.info(self(), :registered_name) do
            {_, []} -> self()
            {_, name} -> name
          end

        :logger.error(
          %{
            label: {GenServer, :no_handle_info},
            report: %{
              module: __MODULE__,
              message: msg,
              name: proc
            }
          },
          %{
            domain: [:otp, :elixir],
            error_logger: %{tag: :error_msg},
            report_cb: &GenServer.format_report/1
          }
        )

        {:noreply, state}
      end

      # Allow overriding handle_event
      defoverridable Kubereq.Connect
    end
  end

  def start_link(handler_module, req, handler_state, opts \\ []) do
    {:ok, resp} =
      req
      |> Req.request(
        kind: "Pod",
        operation: :connect,
        adapter: fn req ->
          {:ok, pid} =
            GenServer.start_link(__MODULE__, {req, handler_module, handler_state}, opts)

          {req, Req.Response.new(status: 101, body: pid)}
        end
      )

    {:ok, resp.body}
  end

  @impl GenServer
  def init({req, handler_module, handler_state}) do
    with {:ok, mint, websocket, ref} <- connect(req),
         {:ok, mint} <- Mint.HTTP.set_mode(mint, :active),
         {:ok, handler_state} <- handler_module.init(handler_state) do
      state =
        struct(__MODULE__,
          mint: mint,
          websocket: websocket,
          ref: ref,
          handler_module: handler_module,
          handler_state: handler_state
        )

      {:ok, state}
    else
      {:error, error} ->
        {:stop, error}

      {:stop, reason} ->
        {:stop, reason}

      {:error, _mint, error} ->
        {:stop, error}
    end
  end

  @impl GenServer
  # Dialyzer doesn't like our pattern matching against opaque types in the error handler
  @dialyzer {:no_opaque, handle_info: 2}
  def handle_info(message, state) when Mint.HTTP.is_connection_message(state.mint, message) do
    ref = state.ref

    with {:ok, mint, [{:data, ^ref, data}]} <- Mint.WebSocket.stream(state.mint, message),
         {:ok, websocket, frames} <- Mint.WebSocket.decode(state.websocket, data) do
      state = %{state | mint: mint, websocket: websocket}
      handle_frame(frames, {:noreply, state})
    else
      {:error, %Mint.WebSocket{} = websocket, error} ->
        {:stop, error, %{state | websocket: websocket}}

      {:error, mint, error, _} ->
        {:stop, error, %{state | mint: mint}}
    end
  end

  def handle_info(msg, state) do
    state.handler_module.handle_info(msg, state.handler_state)
    |> process_result(state)
  end

  defp handle_frame([], result), do: result

  defp handle_frame([frame | frames], result) do
    state = elem(result, 1)

    case state.handler_module.handle_frame(frame, state.handler_state)
         |> process_result(state) do
      {:stop, _reason, _new_user_state} = result ->
        result

      result when elem(frame, 0) == :close ->
        {:stop, :normal, elem(result, 1)}

      result ->
        handle_frame(frames, result)
    end
  end

  @impl GenServer
  def handle_call(:open?, _from, state) do
    {:reply, Mint.HTTP.open?(state.mint)}
  end

  def handle_call(request, from, state) do
    state.handler_module.handle_call(request, from, state.handler_state)
    |> process_result(state)
  end

  @impl GenServer
  # Dialyzer doesn't like our pattern matching against opaque types in the error handler
  @dialyzer {:no_opaque, handle_cast: 2}
  def handle_cast({:send_frame, frame}, state) do
    with {:ok, websocket, data} <- Mint.WebSocket.encode(state.websocket, frame),
         {:ok, mint} <- Mint.WebSocket.stream_request_body(state.mint, state.ref, data) do
      {:noreply, %{state | websocket: websocket, mint: mint}}
    else
      {:error, %Mint.WebSocket{} = websocket, error} ->
        Logger.error(error)
        {:noreply, %{state | websocket: websocket}}

      {:error, mint, error} ->
        Logger.error(error)
        {:noreply, %{state | mint: mint}}
    end
  end

  def handle_cast(request, state) do
    state.handler_module.handle_cast(request, state.handler_state)
    |> process_result(state)
  end

  @impl GenServer
  def handle_continue(continue_arg, state) do
    state.handler_module.handle_continue(continue_arg, state.handler_state)
    |> process_result(state)
  end

  @impl GenServer
  def terminate(reason, state) do
    state.handler_module.terminate(reason, state.handler_state)
  end

  @impl GenServer
  def code_change(old_vsn, state, extra) do
    with {:ok, new_handler_state} <-
           state.handler_module.code_change(old_vsn, state.handler_state, extra) do
      {:ok, %{state | handler_state: new_handler_state}}
    end
  end

  @impl GenServer
  def format_status(
        %{state: %{handler_module: handler_module, handler_state: handler_state} = state} = status
      ) do
    handler_module.format_status(%{status | state: handler_state})
    |> Map.update!(:state, &%{state | handler_state: &1})
  end

  def format_status(format), do: format

  def send_frame(server, frame) do
    GenServer.cast(server, {:send_frame, frame})
  end

  def close(server, code, reason) do
    send_frame(server, {:close, code, reason})
  end

  def open?(server) do
    GenServer.call(server, :open?)
  end

  def connect_and_stream(req, map_frame_fun) do
    with {:ok, mint, websocket, ref} <- connect(req) do
      stream = create_stream(mint, ref, websocket, map_frame_fun)
      {req, Req.Response.new(status: 101, body: stream)}
    end
  end

  defp connect(req) do
    uri = req.url
    {http_scheme, ws_scheme} = ws_scheme(uri.scheme)

    conn_opts =
      req.options.connect_options
      |> Keyword.put(:mode, :passive)
      |> Keyword.put_new(:protocols, [:http1])

    path = uri.path || "/"

    path =
      case uri.query do
        nil -> path
        query -> path <> "?" <> query
      end

    headers = format_headers(req.headers)

    with {:ok, mint} <- Mint.HTTP.connect(http_scheme, uri.host, uri.port, conn_opts),
         {:ok, mint, ref} <- Mint.WebSocket.upgrade(ws_scheme, mint, path, headers),
         {:ok, mint, upgrade_response} <- receive_upgrade_response(mint, ref),
         {:ok, mint, websocket} <-
           Mint.WebSocket.new(
             mint,
             ref,
             upgrade_response.status,
             upgrade_response.headers
           ) do
      {:ok, mint, websocket, ref}
    else
      {:error, error} ->
        {req, error}

      {:error, _, error} ->
        {req, error}
    end
  end

  defp process_result(result, state) do
    case result do
      {no_or_reply, new_handler_state, timeout_continue} when no_or_reply in [:reply, :noreply] ->
        {no_or_reply, %{state | handler_state: new_handler_state}, timeout_continue}

      {no_or_reply, new_handler_state} when no_or_reply in [:reply, :noreply] ->
        {no_or_reply, %{state | handler_state: new_handler_state}}

      {:stop, reason, new_handler_state} ->
        {:stop, reason, %{state | handler_state: new_handler_state}}

      {:stop, reason, reply, new_handler_state} ->
        {:stop, reason, reply, %{state | handler_state: new_handler_state}}
    end
  end

  defp receive_upgrade_response(mint, ref, response \\ %{}) do
    case Mint.HTTP.recv(mint, 0, 10_000) do
      {:ok, mint, parts} ->
        response =
          parts
          |> Map.new(fn
            {type, ^ref} -> {type, true}
            {type, ^ref, value} -> {type, value}
          end)
          |> Map.merge(response)

        if response[:done],
          do: {:ok, mint, response},
          else: receive_upgrade_response(mint, ref, response)

      {:error, mint, error, _} ->
        {:error, mint, error}
    end
  end

  defp create_stream(mint, ref, websocket, map_frame_fun) do
    Stream.resource(
      fn -> {[], mint, ref, websocket} end,
      fn
        {[{:close, _, _} | _], mint, ref, websocket} ->
          {:halt, {mint, ref, websocket}}

        {[frame | rest], mint, ref, websocket} ->
          {[map_frame_fun.(frame)], {rest, mint, ref, websocket}}

        {[], mint, ref, websocket} ->
          with {:ok, mint, [{:data, ^ref, data}]} <- Mint.WebSocket.recv(mint, 0, :infinity),
               {:ok, websocket, frames} <- Mint.WebSocket.decode(websocket, data) do
            {[], {frames, mint, ref, websocket}}
          else
            {:error, _mint, _error} ->
              {:halt, :ok}

            {:ok, mint, _other} ->
              {[], {[], mint, ref, websocket}}
          end
      end,
      fn _ -> :ok end
    )
  end

  defp format_headers(headers) do
    for {name, values} <- headers, value <- values, do: {name, value}
  end

  @spec ws_scheme(binary()) :: {:http, :ws} | {:https, :wss}
  defp ws_scheme("http"), do: {:http, :ws}
  defp ws_scheme("https"), do: {:https, :wss}
end
