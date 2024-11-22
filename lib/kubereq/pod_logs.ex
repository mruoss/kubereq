defmodule Kubereq.PodLogs do
  @moduledoc ~S"""
  Establish a connection to a Pod and stream logs.

  The connection is kept alive until the websocket is closed via `close/1`.
  The bytes received from the container are sent to the process passed via the
  `:into` option.

  ### Examples

      req = Req.new() |> Kubereq.attach()
      Kubereq.PodLogs.start_link(
        req: req,
        into: self(),
        namespace: "default",
        name: "my-pod",
        container: "main-container",
      )
      # Messages in inbox: {:stdout, "log entries"}, {:stdout, "more log entries"}

  ### Arguments

  * `:req` - A `Req.Request` struct with Kubereq attached.
  * `:namespace` - The namespace the Pod runs in
  * `:name` - The name of the Pod
  * `:container` - The container for which to stream logs. Defaults to only
    container if there is one container in the pod. Fails if not defined for
    pods with multiple pods.
  * `:into` - Destination for messages received from the pod. Can be a `pid` or
    a `{pid, ref}` tuple.
  * `:follow` - Follow the log stream of the pod. If this is set to `true`,
    the connection is kept alive which blocks current the process. Defaults to
    `true`.
  * `:insecureSkipTLSVerifyBackend` - insecureSkipTLSVerifyBackend indicates
    that the apiserver should not confirm the validity of the serving
    certificate of the backend it is connecting to. This will make the HTTPS
    connection between the apiserver and the backend insecure. This means the
    apiserver cannot verify the log data it is receiving came from the real
    kubelet. If the kubelet is configured to verify the apiserver's TLS
    credentials, it does not mean the connection to the real kubelet is
    vulnerable to a man in the middle attack (e.g. an attacker could not
    intercept the actual log data coming from the real kubelet).
  * `:limitBytes` - If set, the number of bytes to read from the server before
    terminating the log output. This may not display a complete final line of
    logging, and may return slightly more or slightly less than the specified
    limit.
  * `:pretty` - If 'true', then the output is pretty printed.
  * `:previous` - Return previous terminated container logs. Defaults to `false`.
  * `:sinceSeconds` - A relative time in seconds before the current time from
    which to show logs. If this value precedes the time a pod was started,
    only logs since the pod start will be returned. If this value is in the
    future, no logs will be returned. Only one of sinceSeconds or sinceTime
    may be specified.
  * `:tailLines` - If set, the number of lines from the end of the logs to
    show. If not specified, logs are shown from the creation of the container
    or sinceSeconds or sinceTime
  * `:timestamps` - If true, add an RFC3339 or RFC3339Nano timestamp at the
    beginning of every line of log output. Defaults to `false`.
  * `:opts` (optional) - Additional options passed to `Req`
  """
  use Kubereq.Connect

  def start_link(args) do
    {into, args} = Keyword.pop!(args, :into)
    {req, args} = Keyword.pop!(args, :req)

    opts =
      args
      |> Keyword.put(:subresource, "log")
      |> Kubereq.Connect.args_to_opts()

    Kubereq.Connect.start_link(__MODULE__, req: req, state: %{into: into}, opts: opts)
  end

  defdelegate open?(dest), to: Fresh
  defdelegate close(dest, code, reason), to: Fresh

  @doc """
  Close the connection and terminate the process.
  """
  @spec close(dest :: :gen_statem.server_ref()) :: :ok
  def close(dest), do: Fresh.send(dest, {:close, 1000, ""})

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
