defmodule Kubereq.PodExec do
  @moduledoc ~S"""
  Establish a connection to a Pod and execute a command in a container.

  The connection is kept alive until the websocket is closed by the counterpart.
  The bytes received from the container are sent to the process passed via the
  `:into` option. Bytes sent to this process via `send_stdin/2` are forwarded to
  the container.

  ### Examples

  When the command terminates, the websocket is automatically closed and the
  process terminates.

      req = Req.new() |> Kubereq.attach()
      Kubereq.PodExec.start_link(
        req: req,
        namespace: "default",
        name: "my-pod",
        container: "main",
        into: self(),
        command: ["/bin/sh", "-c", "echo foo"],
        stdin: true,
        stdout: true,
        stderr: true
        tty: false,
      )
      # Messages in inbox: {:stdout, "foo\n"}, {:close, 1000, ""}

  Passing the path to a shell as command will keep the socket open. Together
  with `:stdin`, `:stdout`, `:stderr` and `:tty`, this can be used to implement
  an interactive shell:

      req = Req.new() |> Kubereq.attach()
      {:ok, dest} = Kubereq.PodExec.start_link(
        req: req,
        namespace: "default",
        name: "my-pod",
        container: "main",
        into: self(),
        command: ["/bin/sh"],
        stdin: true,
        stdout: true,
        stderr: true
        tty: false,
      )
      # Message in inbox: {:stdout, "sh-5.2# "}

      Kubereq.PodExec.send_stdin(dest, "echo foo")
      # Message in inbox: {:stdout, "echo foo\r\nfoo\r\nsh-5.2# "}

  ### Arguments

  * `:req` - A `Req.Request` struct with Kubereq attached.
  * `:namespace` - The namespace the Pod runs in
  * `:name` - The name of the Pod
  * `:container` (optional) - The container for which to stream logs. Defaults to only
    container if there is one container in the pod. Fails if not defined for
    pods with multiple pods.
  * `:into` - Destination for messages received from the pod. Can be a `pid` or
    a `{pid, ref}` tuple.
  * `:command` - Command is the remote command to execute. Not executed within a shell.
  * `:stdin` (optional) - Redirect the standard input stream of the pod for this call. Defaults to `true`.
  * `:stdin` (optional) - Redirect the standard output stream of the pod for this call. Defaults to `true`.
  * `:stderr` (optional) - Redirect the standard error stream of the pod for this call. Defaults to `true`.
  * `:tty` (optional) - If `true` indicates that a tty will be allocated for the exec call. Defaults to `false`.
  * `:opts` (optional) - Additional options passed to `Req`
  """
  use Kubereq.Connect

  @stdout 0x01
  @stderr 0x02
  @err 0x03

  def start_link(args) do
    {into, args} = Keyword.pop!(args, :into)
    {req, args} = Keyword.pop!(args, :req)

    opts =
      args
      |> Keyword.put(:subresource, "exec")
      |> args_to_opts()

    req = Req.merge(req, opts)

    Kubereq.Connect.start_link(__MODULE__, req, %{into: into})
  end

  def child_spec(init_arg) do
    default = %{
      id: __MODULE__,
      start: {Kubereq.PodExec, :start_link, [init_arg]}
    }

    Supervisor.child_spec(default, [])
  end

  @doc """
  Check if the websocket is open.
  """
  defdelegate open?(dest), to: Kubereq.Connect

  @doc """
  Send a close frame to close the websocket.
  """
  defdelegate close(dest, code, reason), to: Kubereq.Connect

  @doc """
  Send the given `data` to the container.
  """
  @spec send_stdin(dest :: :gen_statem.server_ref(), data :: binary()) :: :ok
  def send_stdin(dest, data) do
    Kubereq.Connect.send_frame(dest, {:text, <<0, data::binary>>})
  end

  @doc """
  Close the connection and terminate the process.
  """
  @spec close(dest :: :gen_statem.server_ref()) :: :ok
  def close(dest), do: Kubereq.Connect.send_frame(dest, {:close, 1000, ""})

  @impl Kubereq.Connect
  def init(state) do
    send_frame(state.into, :connected)
    {:ok, state}
  end

  @impl Kubereq.Connect
  def handle_frame(frame, state) do
    data = map_frame(frame)
    send_frame(state.into, data)
    {:noreply, state}
  end

  defp send_frame({dest, ref}, frame), do: send(dest, {ref, frame})
  defp send_frame(dest, frame), do: send(dest, frame)

  def connect_and_stream(req) do
    Kubereq.Connect.connect_and_stream(req, &map_frame/1)
  end

  defp map_frame(frame) do
    case frame do
      {:binary, <<@stdout, msg::binary>>} ->
        {:stdout, msg}

      {:binary, <<@stderr, msg::binary>>} ->
        {:stderr, msg}

      {:binary, <<@err, msg::binary>>} ->
        {:error, msg}

      other ->
        other
    end
  end

  @path_params [:namespace, :name]
  @exec_params [:container, :command, :stdin, :stdout, :stderr, :tty]
  def args_to_opts(args) do
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
