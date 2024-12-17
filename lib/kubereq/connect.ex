defmodule Kubereq.Connect do
  @moduledoc false
  defmacro __using__(opts) do
    quote location: :keep do
      @behaviour Fresh

      @doc false
      def child_spec(args) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [args]},
          restart: :transient
        }
        |> Supervisor.child_spec(unquote(Macro.escape(opts)))
      end

      @doc false
      def start_link(args) do
        Kubereq.Connect.start_link(__MODULE__, args)
      end

      @doc false
      def start(args) do
        Kubereq.Connect.start(__MODULE__, args)
      end

      @doc false
      def handle_connect(_status, _headers, state), do: {:ok, state}

      @doc false
      def handle_control(_message, state), do: {:ok, state}

      @doc false
      def handle_in(frame, state), do: Kubereq.Connect.handle_in(__MODULE__, frame, state)

      @doc false
      def handle_info(_message, state), do: {:ok, state}

      @doc false
      def handle_error({error, _reason}, state)
          when error in [:encoding_failed, :casting_failed],
          do: {:ignore, state}

      def handle_error(_error, _state), do: :reconnect

      @doc false
      def handle_disconnect(_code, _reason, _state), do: :close

      @doc false
      def handle_terminate(_reason, _state), do: :ok

      defoverridable child_spec: 1,
                     start_link: 1,
                     start: 1,
                     handle_connect: 3,
                     handle_control: 2,
                     handle_in: 2,
                     handle_info: 2,
                     handle_disconnect: 3,
                     handle_terminate: 2
    end
  end

  defdelegate close(dest, code, reason), to: Fresh
  defdelegate open?(dest), to: Fresh

  @spec close(dest :: :gen_statem.server_ref()) :: :ok
  def close(dest), do: Fresh.send(dest, {:close, 1000, ""})

  @doc false
  def start_link(module, args) do
    do_start(module, args, &Fresh.start_link/4)
  end

  @doc false
  def start(module, args) do
    do_start(module, args, &Fresh.start/4)
  end

  defp do_start(module, args, start_callback) do
    req = Keyword.fetch!(args, :req)
    state = Keyword.fetch!(args, :state)
    opts = Keyword.fetch!(args, :opts)

    {:ok, resp} =
      req
      |> Req.merge(
        kind: "Pod",
        operation: :connect,
        adapter: &run(&1, module, state, start_callback)
      )
      |> Req.request(opts)

    {:ok, resp.body}
  end

  defp run(req, module, state, start) do
    {_, _, scheme} = ws_scheme(req.url.scheme)

    uri = %{req.url | scheme: scheme}

    headers = format_headres(req.headers)
    opts = Keyword.merge(req.options.connect_options, headers: headers)

    {:ok, pid} = start.(uri, module, state, opts)
    {req, Req.Response.new(status: 101, body: pid)}
  end

  def run(req, map_frame_fun) do
    uri = req.url
    {http_scheme, ws_scheme, _} = ws_scheme(uri.scheme)
    path = uri.path || "/"

    path =
      case uri.query do
        nil -> path
        query -> path <> "?" <> query
      end

    conn_opts =
      req.options.connect_options
      |> Keyword.put(:mode, :passive)
      |> Keyword.put_new(:protocols, [:http1])

    headers = format_headres(req.headers)

    with {:ok, conn} <- Mint.HTTP.connect(http_scheme, uri.host, uri.port, conn_opts),
         {:ok, conn} <- Mint.HTTP.set_mode(conn, :passive),
         {:ok, conn, ref} <- Mint.WebSocket.upgrade(ws_scheme, conn, path, headers),
         {:ok, conn, upgrade_response} <- receive_upgrade_response(conn, ref),
         {:ok, conn, websocket} <-
           Mint.WebSocket.new(
             conn,
             ref,
             upgrade_response.status,
             upgrade_response.headers
           ) do
      stream = create_stream(conn, ref, websocket, map_frame_fun)
      {req, Req.Response.new(status: 101, body: stream)}
    else
      {:error, error} ->
        {req, error}

      {:error, _, error} ->
        {req, error}
    end
  end

  defp format_headres(headers) do
    for {name, values} <- headers, value <- values, do: {name, value}
  end

  defp create_stream(conn, ref, websocket, map_frame_fun) do
    Stream.resource(
      fn -> {[], conn, ref, websocket} end,
      fn
        {[{:close, _, _} | _], conn, ref, websocket} ->
          {:halt, {conn, ref, websocket}}

        {[frame | rest], conn, ref, websocket} ->
          {[map_frame_fun.(frame)], {rest, conn, ref, websocket}}

        {[], conn, ref, websocket} ->
          with {:ok, conn, [{:data, ^ref, data}]} <- Mint.WebSocket.recv(conn, 0, :infinity),
               {:ok, websocket, frames} <- Mint.WebSocket.decode(websocket, data) do
            {[], {frames, conn, ref, websocket}}
          else
            {:error, _conn, _error} ->
              {:halt, :ok}

            {:ok, conn, _other} ->
              {[], {[], conn, ref, websocket}}
          end
      end,
      fn _ -> :ok end
    )
  end

  @spec ws_scheme(binary()) :: {:http, :ws, binary()} | {:https, :wss, binary()}
  defp ws_scheme("http"), do: {:http, :ws, "ws"}
  defp ws_scheme("https"), do: {:https, :wss, "wss"}

  defp receive_upgrade_response(conn, ref) do
    Enum.reduce_while(Stream.cycle([:ok]), {conn, %{}}, fn _, {conn, response} ->
      case Mint.HTTP.recv(conn, 0, 10_000) do
        {:ok, conn, parts} ->
          response =
            parts
            |> Map.new(fn
              {type, ^ref} -> {type, true}
              {type, ^ref, value} -> {type, value}
            end)
            |> Map.merge(response)

          # credo:disable-for-lines:3
          if response[:done],
            do: {:halt, {:ok, conn, response}},
            else: {:cont, {conn, response}}

        {:error, conn, error, _} ->
          {:halt, {:error, conn, error}}
      end
    end)
  end
end
