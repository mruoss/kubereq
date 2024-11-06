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

  def start_link(args) do
    {into, args} = Keyword.pop!(args, :into)
    {req, args} = Keyword.pop!(args, :req)

    opts =
      args
      |> Keyword.put(:subresource, "exec")
      |> Kubereq.Connect.args_to_opts()

    Kubereq.Connect.start_link(__MODULE__, req: req, state: %{into: into}, opts: opts)
  end

  defdelegate open?(dest), to: Fresh
  defdelegate close(dest, code, reason), to: Fresh

  @doc """
  Send the given `data` to the container.
  """
  @spec send_stdin(dest :: :gen_statem.server_ref(), data :: binary()) :: :ok
  def send_stdin(dest, data) do
    Fresh.send(dest, {:text, <<0, data::binary>>})
  end

  @doc """
  Close the connection and terminate the process.
  """
  @spec close(dest :: :gen_statem.server_ref()) :: :ok
  def close(dest), do: Fresh.send(dest, {:close, 1000, ""})

  def handle_connect(_status, _headers, state) do
    send_frame(state.into, :connected)
    {:ok, state}
  end

  def handle_disconnect(code, reason, state) do
    send_frame(state.into, {:close, code, reason})
    :close
  end

  def handle_in_stdout(frame, state) do
    send_frame(state.into, {:stdout, frame})
    {:ok, state}
  end

  def handle_in_stderr(frame, state) do
    send_frame(state.into, {:stderr, frame})
    {:ok, state}
  end

  def handle_in_error(frame, state) do
    send_frame(state.into, {:error, frame})
    {:ok, state}
  end

  defp send_frame({dest, ref}, frame), do: send(dest, {ref, frame})
  defp send_frame(dest, frame), do: send(dest, frame)
end
