defmodule Kubereq.Connect do
  @moduledoc false

  @stdout 0x01
  @stderr 0x02
  @err 0x03

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
      def handle_in_stdout(_message, state), do: {:ok, state}

      @doc false
      def handle_in_stderr(_message, state), do: {:ok, state}

      @doc false
      def handle_in_error(_message, state), do: {:ok, state}

      @doc false
      def handle_binary(_message, state), do: {:ok, state}

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
                     handle_error: 2,
                     handle_disconnect: 3,
                     handle_terminate: 2,
                     handle_in_stdout: 2,
                     handle_in_stderr: 2,
                     handle_in_error: 2
    end
  end

  defdelegate close(dest, code, reason), to: Fresh
  defdelegate open?(dest), to: Fresh

  def send_stdin(dest, data) do
    Fresh.send(dest, {:text, <<0, data::binary>>})
  end

  @spec close(dest :: :gen_statem.server_ref()) :: :ok
  def close(dest), do: Fresh.send(dest, {:close, 1000, ""})

  def handle_in(module, frame, state) do
    case map_frame(frame) do
      {:stdout, msg} -> module.handle_in_stdout(msg, state)
      {:stderr, msg} -> module.handle_in_stderr(msg, state)
      {:error, msg} -> module.handle_in_error(msg, state)
    end
  end

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

  def run(req) do
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
      stream = create_stream(conn, ref, websocket)
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

  defp create_stream(conn, ref, websocket) do
    Stream.resource(
      fn -> {[], conn, ref, websocket} end,
      fn
        {[{:close, _, _} | _], conn, ref, websocket} ->
          {:halt, {conn, ref, websocket}}

        {[frame | rest], conn, ref, websocket} ->
          {[map_frame(frame)], {rest, conn, ref, websocket}}

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

  defp map_frame(frame) do
    case frame do
      {:binary, <<@stdout, msg::binary>>} -> {:stdout, msg}
      {:binary, <<@stderr, msg::binary>>} -> {:stderr, msg}
      {:binary, <<@err, msg::binary>>} -> {:error, msg}
      {:binary, msg} -> {:stdout, msg}
      other -> other
    end
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

  @path_params [:name, :namespace]

  @doc """
  Turns arguments passed to a connect function to `Req` options to be passed to
  `Req.request()`
  """
  @spec args_to_opts(args :: Keyword.t()) :: Keyword.t()
  def args_to_opts(args) do
    case Keyword.fetch!(args, :subresource) do
      "log" -> log_args_to_opts(args)
      "exec" -> exec_args_to_opts(args)
    end
  end

  @log_params [
    :container,
    :follow,
    :insecureSkipTLSVerifyBackend,
    :limitBytes,
    :pretty,
    :previous,
    :sinceSeconds,
    :tailLines,
    :timestamps
  ]
  defp log_args_to_opts(args) do
    {params, args} = Keyword.split(args, @log_params)
    {path_params, args} = Keyword.split(args, @path_params)

    params = Keyword.put_new(params, :follow, true)
    Keyword.merge(args, params: params, path_params: path_params)
  end

  @exec_params [:container, :command, :stdin, :stdout, :stderr, :tty]
  defp exec_args_to_opts(args) do
    {params, args} = Keyword.split(args, @exec_params)
    {path_params, args} = Keyword.split(args, @path_params)

    params =
      params
      |> Keyword.get_values(:command)
      |> format_commands()
      |> Keyword.merge(stdin: true, stdout: true, stderr: true)
      |> Keyword.merge(Keyword.delete(params, :command))

    Keyword.merge(args, params: params, path_params: path_params)
  end

  defp format_commands([command]) when is_binary(command) do
    [command: command]
  end

  defp format_commands([commands]) when is_list(commands) do
    format_commands(commands)
  end

  defp format_commands(commands) when is_list(commands) do
    Enum.map(commands, &{:command, &1})
  end
end
