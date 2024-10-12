defmodule Kubereq do
  @moduledoc ~S"""
  Kubereq processes requests to your Kubernetes API Server.

  ## Usage

  This library can used with plan `Req` but the function in this module
  provide an easier API to people used to `kubectl` and friends.

  ### Plain Req

  Use `Kubereq.Kubeconfig.Default` to create connection to cluster and
  plain `Req.request()` to make the request

  ```
  req = Req.new() |> Kubereq.attach()

  Req.request!(req,
    api_version: "v1",
    kind: "ServiceAccount",
    operation: :get,
    path_params: [namespace: "default", name: "default"]
  )
  ```

  You can pass your own Kubeconfigloader pipeline when attaching:

  ```
  req = Req.new() |> Kubereq.attach(kubeconfig: {Kubereq.Kubeconfig.File, path: "/path/to/kubeconfig.yaml"})

  Req.request!(req,
    api_version: "v1",
    kind: "ServiceAccount",
    operation: :get,
    path_params: [namespace: "default", name: "default"]
  )
  ```

  Prepare a `Req` struct for a specific resource:

  ```
  sa_req = Req.new() |> Kubereq.attach(api_version: "v1", kind: "ServiceAccount")

  Req.request!(sa_req,  operation: :get, path_params: [namespace: "default", name: "default"])
  Req.request!(sa_req,  operation: :list, path_params: [namespace: "default"])
  ```

  ### Kubectl API

  While this library can attach to any `Req` struct, it is sometimes easier
  to prepare `Req` for a specific resource and then use the functions
  defined in the `Kubereq` module.

  ```
  sa_req = Req.new() |> Kubereq.attach(api_version: "v1", kind: "ServiceAccount")

  Kubereq.get(sa_req, "my-namespace", "default")
  Kubereq.list(sa_req, "my-namespace")
  ```

  Or use the functions right away, defining the resource through options:

  ```
  req = Req.new() |> Kubereq.attach()

  Kubereq.get(req, "my-namespace", "default", api_version: "v1", kind: "ServiceAccount")

  # get the "status" subresource of the default namespace
  Kubereq.get(req, "my-namespace", api_version: "v1", kind: "Namespace", subresource: "status")
  ```

  For resources defined by Kubernetes, the `api_version` can be omitted:

  ```
  Req.new()
  |> Kubereq.attach(kind: "Namespace")
  |> Kubereq.get("my-namespace")
  ```

  ## Options

  `kubereq` registeres the following options with `Req`:

    * `:kubeconfig` - A `%Kubereq.Kubeconfig{}` struct. The `attach/2` function also accepts a
      Kubeconf pipeline (e.g. `Kubereq.Kubeconfig.Default`)
    * `:api_version` - The group and version of the targeted resource (case sensitive)
    * `:kind` - The kind of the targeted resource (case sensitive)
    * `:resource_path` - Can be defined instead of `:api_version` and `:kind`. The path to the
      targeted resource with placeholders for `:namespace` and `:name`
      (e.g. `api/v1/namespaces/:namespace/configmaps/:name`)
    * `:field_selectors` - See `Kubereq.Step.FieldSelector`
    * `:label_selectors` - See `Kubereq.Step.LabelSelector`
    * `:operation` - The operation on the resource (one of `:create`, `:get` `:update`,
      `:delete`, `:delete_all`, `:apply`, `:json_patch`, `:merge_patch`, `:watch`)
    * `:subresource` - Some operations can be performed on subresources
      (e.g. `status` or `scale`)
  """

  alias Kubereq.Step

  @type wait_until_callback :: (map() | :deleted -> boolean | {:error, any})
  @type wait_until_response :: :ok | {:error, :watch_timeout}
  @type response() :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  @type namespace() :: String.t() | nil
  @type subresource() :: String.t() | nil
  @type watch_response :: {:ok, Enumerable.t(map())} | {:ok, Task.t()} | {:error, Exception.t()}
  @typep do_watch_response :: {:ok, Enumerable.t(map())} | {:error, Exception.t()}

  @deprecated "Use Kubereq.attach/2"
  @spec new(kubeconfig :: Kubereq.Kubeconfig.t()) :: Req.Request.t()
  def new(kubeconfig) do
    attach(Req.new(), kubeconfig: kubeconfig)
  end

  @deprecated "Use Kubereq.attach/2"
  @spec new(kubeconfig :: Kubereq.Kubeconfig.t(), resource_path :: binary()) :: Req.Request.t()
  def new(kubeconfig, resource_path) do
    attach(Req.new(), kubeconfig: kubeconfig, resource_path: resource_path)
  end

  @doc """
  Attaches `kubereq` to a `Req.Request` struct for making HTTP requests to a Kubernetes
  cluster. You can optionally pass a Kubernetes configuration or pipeline via
  `kubeconfig` option. If it is omitted, the default config
  `Kubereq.Kubeconfig.Default` is loaded.

  ### Examples

      iex> Req.new() |> Kubereq.attach()
      %Request.Req{...}
  """
  @spec attach(req :: Req.Request.t(), opts :: Keyword.t()) :: Req.Request.t()
  def attach(req, opts \\ []) do
    options =
      opts
      |> Keyword.put_new(:kubeconfig, Kubereq.Kubeconfig.Default)
      |> Keyword.update!(:kubeconfig, fn
        %Kubereq.Kubeconfig{} = kubeconfig -> kubeconfig
        pipeline -> Kubereq.Kubeconfig.load(pipeline)
      end)

    req
    |> Step.attach()
    |> Req.merge(options)
  end

  @doc """
  Create the `resource` or its `subresource` on the cluster.

  ### Example

      iex> Req.new()
      ...> |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      ...> |> Kubereq.create(resource)
      {:ok, %Req.Response{status: 201, body: %{...}}}
  """
  @spec create(Req.Request.t(), resource :: map(), opts :: Keyword.t()) :: response()
  def create(req, resource, opts \\ []) do
    options =
      Keyword.merge(opts,
        operation: :create,
        json: resource,
        path_params: [
          namespace: resource["metadata"]["namespace"],
          name: resource["metadata"]["name"]
        ]
      )

    Req.request(req, options)
  end

  @doc """
  Get the resource `name` in `namespace` or its `subresource`.

  Omit `namespace` to get cluster resources.

  ### Example

      iex> Req.new()
      ...> |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      ...> |> Kubereq.get("default", "foo")
      {:ok, %Req.Response{status: 200, body: %{...}}}
  """
  @spec get(
          Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: Keyword.t() | nil
        ) ::
          response()
  def get(req, namespace \\ nil, name, opts \\ [])

  def get(req, name, opts, []) when is_list(opts), do: get(req, nil, name, opts)

  def get(req, namespace, name, opts) do
    options =
      Keyword.merge(opts, operation: :get, path_params: [namespace: namespace, name: name])

    Req.request(req, options)
  end

  @doc """
  Get a resource list.

  ### Examples

      iex> Req.new()
      ...> |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      ...> |> Kubereq.list("default")
      {:ok, %Req.Response{status: 200, body: %{...}}}
  """
  @spec list(Req.Request.t(), namespace :: namespace(), opts :: keyword()) :: response()
  def list(req, namespace \\ nil, opts \\ [])

  def list(req, opts, []) when is_list(opts), do: list(req, nil, opts)

  def list(req, namespace, opts) do
    options =
      Keyword.merge(opts,
        operation: :list,
        field_selectors: opts[:field_selectors],
        label_selectors: opts[:label_selectors],
        path_params: [namespace: namespace]
      )

    Req.request(req, options)
  end

  @doc """
  Deletes the `resource` or its `subresource` from the cluster.

  ### Examples

      iex> Req.new()
      ...> |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      ...> |> Kubereq.delete("default", "foo")
      {:ok, %Req.Response{status: 200, body: %{...}}}
  """
  @spec delete(
          Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: Keyword.t()
        ) ::
          response()
  def delete(req, namespace \\ nil, name, opts \\ [])

  def delete(req, name, opts, []) when is_list(opts), do: delete(req, nil, name, opts)

  def delete(req, namespace, name, opts) do
    options =
      Keyword.merge(opts, operation: :delete, path_params: [namespace: namespace, name: name])

    Req.request(req, options)
  end

  @doc """
  Deletes all resources in the given namespace.

  ### Examples

      iex> Req.new()
      ...> |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      ...> |> Kubereq.delete_all("default", label_selectors: [{"app", "my-app"}])
      {:ok, %Req.Response{status: 200, body: %{...}}}

  """
  @spec delete_all(Req.Request.t(), namespace :: namespace(), opts :: keyword()) :: response()
  def delete_all(req, namespace \\ nil, opts \\ [])

  def delete_all(req, opts, []) when is_list(opts), do: delete_all(req, nil, opts)

  def delete_all(req, namespace, opts) do
    options = Keyword.merge(opts, operation: :delete_all, path_params: [namespace: namespace])
    Req.request(req, options)
  end

  @doc """
  Updates the given `resource`.

  ### Examples

      iex> Req.new()
      ...> |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      ...> |> Kubereq.update(resource)
      {:ok, %Req.Response{status: 200, body: %{...}}}
  """
  @spec update(Req.Request.t(), resource :: map(), opts :: Keyword.t()) :: response()
  def update(req, resource, opts \\ []) do
    options =
      Keyword.merge(opts,
        operation: :update,
        json: resource,
        path_params: [
          namespace: get_in(resource, ~w(metadata namespace)),
          name: get_in(resource, ~w(metadata name))
        ]
      )

    Req.request(req, options)
  end

  @doc """
  Applies the given `resource` using a Server-Side-Apply Patch.

  See the [documentation](https://kubernetes.io/docs/reference/using-api/server-side-apply/)
  for a documentation on `field_manager` and `force` arguments.

  ### Examples

      iex> Req.new()
      ...> |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      ...> |> Kubereq.apply(resource)
      {:ok, %Req.Response{status: 200, body: %{...}}}
  """
  @spec apply(
          Req.Request.t(),
          resource :: map(),
          field_manager :: binary(),
          force :: boolean(),
          opts :: Keyword.t()
        ) :: response()
  def apply(req, resource, field_manager \\ "Elixir", force \\ true, opts \\ [])

  def apply(req, resource, opts, _, _) when is_list(opts) do
    apply(req, resource, "Elixir", true, opts)
  end

  def apply(req, resource, field_manager, force, opts) do
    options =
      Keyword.merge(opts,
        operation: :apply,
        path_params: [
          namespace: get_in(resource, ~w(metadata namespace)),
          name: get_in(resource, ~w(metadata name))
        ],
        params: [fieldManager: field_manager, force: force],
        json: resource
      )

    Req.request(req, options)
  end

  @doc """
  Patches the resource `name`in `namespace` or its `subresource` using the given
  `json_patch`.

  ### Examples

      iex> Req.new()
      ...> |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      ...> |> Kubereq.json_patch(%{...}, "default", "foo")
      {:ok, %Req.Response{...}
  """
  @spec json_patch(
          Req.Request.t(),
          json_patch :: map(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: Keyword.t()
        ) :: response()
  def json_patch(req, json_patch, namespace \\ nil, name, opts \\ [])

  def json_patch(req, json_patch, name, opts, []) when is_list(opts) do
    json_patch(req, json_patch, nil, name, opts)
  end

  def json_patch(req, json_patch, namespace, name, opts) do
    options =
      Keyword.merge(opts,
        operation: :json_patch,
        path_params: [namespace: namespace, name: name],
        json: json_patch
      )

    Req.request(req, options)
  end

  @doc """
  Patches the resource `name`in `namespace` or its `subresource` using the given
  `merge_patch`.

  ### Examples

      iex> Req.new()
      ...> |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      ...> |> Kubereq.merge_patch(%{...}, "default", "foo")
      {:ok, %Req.Response{...}

  """
  @spec merge_patch(
          Req.Request.t(),
          merge_patch :: String.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: Keyword.t()
        ) :: response()
  def merge_patch(req, merge_patch, namespace \\ nil, name, opts \\ [])

  def merge_patch(req, merge_patch, name, opts, []) when is_list(opts) do
    merge_patch(req, merge_patch, nil, name, opts)
  end

  def merge_patch(req, merge_patch, namespace, name, opts) do
    options =
      Keyword.merge(opts,
        operation: :merge_patch,
        path_params: [namespace: namespace, name: name],
        json: merge_patch
      )

    Req.request(req, options)
  end

  @doc """
  GET a resource and wait until the given `callback` returns true or the given
  `timeout` (ms) has expired.

  ### Options

  All options described in the moduledoc plus:

  * `timeout` - Timeout in ms after function terminates with `{:error, :timeout}`
  """
  @spec wait_until(
          Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          callback :: wait_until_callback(),
          opts :: Keyword.t()
        ) :: wait_until_response()
  def wait_until(req, namespace \\ nil, name, callback, opts \\ [])

  def wait_until(req, name, callback, opts, []) when is_list(opts) do
    wait_until(req, nil, name, callback, opts)
  end

  def wait_until(req, namespace, name, callback, opts) do
    {timeout, opts} = Keyword.pop(opts, :timeout, 10_000)
    ref = make_ref()
    opts = Keyword.put(opts, :field_selectors, [{"metadata.name", name}])

    with {:ok, resp} <- list(req, namespace, opts),
         {:init, false} <- {:init, callback.(List.first(resp.body["items"]) || :deleted)} do
      {:ok, watch_task} =
        watch(
          req,
          namespace,
          Keyword.merge(opts,
            resource_version: resp.body["metadata"]["resourceVersion"],
            stream_to: {self(), ref}
          )
        )

      timer = Process.send_after(self(), {ref, :timeout}, timeout)
      result = wait_event_loop(ref, callback)
      Task.shutdown(watch_task)
      Process.cancel_timer(timer)
      result
    else
      {:init, true} -> :ok
      {:init, {:error, error}} -> {:error, error}
      {:error, error} -> {:error, error}
    end
  end

  defp wait_event_loop(ref, callback) do
    receive do
      {^ref, %{"type" => "DELETED"}} ->
        case callback.(:deleted) do
          true -> :ok
          false -> :ok
          :ok -> :ok
          {:error, error} -> {:error, error}
        end

      {^ref, %{"object" => resource}} ->
        if callback.(resource), do: :ok, else: wait_event_loop(ref, callback)

      {^ref, :timeout} ->
        {:error, :watch_timeout}
    end
  end

  @doc """
  Watch events of all resources in `namespace`.

  ### Examples

      iex> Req.new()
      ...> |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      ...> |> Kubereq.watch("default")
      {:ok, #Function<60.48886818/2 in Stream.transform/3>}

  Omit the second argument in order to watch events in all namespaces:

      iex> Req.new()
      ...> |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      ...> |> Kubereq.watch()
      {:ok, #Function<60.48886818/2 in Stream.transform/3>}

  ### Options

  All options described in the moduledoc plus:

  * `:resource_version` - If given, starts to stream from the given `resourceVersion` of the resource list. Otherwise starts streaming from HEAD.
  * `:stream_to` - If set to a `pid`, streams events to the given pid. If set to `{pid, ref}`, the messages are in the form `{ref, event}`.
  """
  @spec watch(
          Req.Request.t(),
          namespace :: namespace(),
          opts :: keyword()
        ) ::
          watch_response()
  def watch(req, namespace \\ nil, opts \\ [])

  def watch(req, opts, []) when is_list(opts) do
    watch(req, nil, opts)
  end

  def watch(req, namespace, opts) do
    {resource_version, opts} = Keyword.pop(opts, :resource_version)
    {steam_to, opts} = Keyword.pop(opts, :stream_to)
    do_watch = fn -> do_watch(req, namespace, resource_version, opts) end

    case steam_to do
      nil ->
        do_watch.()

      {pid, ref} ->
        task = watch_create_task(do_watch, &send(pid, {ref, &1}))
        {:ok, task}

      pid ->
        task = watch_create_task(do_watch, &send(pid, &1))
        {:ok, task}
    end
  end

  @doc """
  Watch events of a single resources `name`in `namespace`.
  The `req` struct should have been created using `Kubereq.new/1`.

  ### Examples

      iex> Req.new()
      ...> |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      ...> |> Kubereq.watch_single("default")
      {:ok, #Function<60.48886818/2 in Stream.transform/3>}

  Omit the second argument in order to watch events in all namespaces:

      iex> Req.new()
      ...> |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      ...> |> Kubereq.watch_single()
      {:ok, #Function<60.48886818/2 in Stream.transform/3>}

  ### Options

  All options described in the moduledoc plus:

  * `:stream_to` - If set to a `pid`, streams events to the given pid. If set to `{pid, ref}`, the messages are in the form `{ref, event}`

  """
  @spec watch_single(
          Req.Request.t(),
          namespace :: namespace(),
          name :: String.t()
        ) ::
          watch_response()
  @spec watch_single(
          Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: keyword()
        ) :: watch_response()
  def watch_single(req, namespace \\ nil, name, opts \\ [])

  def watch_single(req, name, opts, []) when is_list(opts) do
    watch_single(req, nil, name, opts)
  end

  def watch_single(req, namespace, name, opts) do
    opts = Keyword.put(opts, :field_selectors, [{"metadata.name", name}])
    watch(req, namespace, opts)
  end

  @spec watch_create_task(
          (-> do_watch_response()),
          (map() -> any())
        ) :: Task.t()
  defp watch_create_task(do_watch_callback, send_callback) do
    Task.async(fn ->
      case do_watch_callback.() do
        {:ok, stream} ->
          stream
          |> Stream.map(send_callback)
          |> Stream.run()

        {:error, error} ->
          send_callback.({:error, error})
      end
    end)
  end

  @spec do_watch(
          Req.Request.t(),
          namespace :: namespace(),
          resource_version :: integer() | String.t(),
          opts :: keyword()
        ) :: do_watch_response()
  defp do_watch(req, namespace, nil, opts) do
    with {:ok, resp} <- list(req, namespace, opts) do
      resource_version = resp.body["metadata"]["resourceVersion"]
      do_watch(req, namespace, resource_version, opts)
    end
  end

  defp do_watch(req, namespace, resource_version, opts) do
    with {:ok, resp} <-
           Req.get(req,
             operation: :watch,
             field_selectors: opts[:field_selectors],
             label_selectors: opts[:label_selectors],
             path_params: [namespace: namespace],
             receive_timeout: :infinity,
             into: :self,
             params: [
               watch: "1",
               allowWatchBookmarks: "1",
               resourceVersion: resource_version
             ]
           ) do
      stream =
        resp
        |> Kubereq.Watch.create_stream()
        |> Kubereq.Watch.transform_to_objects()

      {:ok, stream}
    end
  end

  @doc """

  Opens a websocket to the given Pod and streams logs from it.

  ## Options

  * `:params` - Map defining the query parameteres added to the request to the
    `pods/log` subresource. The `log` subresource supports the following
    paremeters:

    * `container` -  (optional) Specifies the container for which to return
      logs. If omitted, returns logs for the first container in the pod.
    * `follow` - (optional) If set to true, the request will stay open and
      continue to return new log entries as they are generated. Default is
      false.
    * `previous` - (optional) If true, return logs from previous terminated
      containers. Default is false.
    * `sinceSeconds` - (optional) Returns logs newer than a relative duration in
      seconds. Conflicts with sinceTime.
    * `sinceTime` - (optional) Returns logs after a specific date (RFC3339
      format). Conflicts with sinceSeconds.
    * `timestamps` - (optional) If true, add an RFC3339 timestamp at the
      beginning of every line. Default is false.
    * `tailLines` - (optional) Specifies the number of lines from the end of the
      logs to show. If not specified, logs are shown from the creation of the
      container or sinceSeconds/sinceTime.
    * `limitBytes` - (optional) The maximum number of bytes to return from the
      server. If not specified, no limit is imposed.
    * `insecureSkipTLSVerifyBackend` - (optional) If true, bypasses certificate
      verification for the kubelet's HTTPS endpoint. This is useful for clusters
      with self-signed certificates. Default is false.
    * `pretty` - (optional) If true, formats the output in a more readable
      format. This is typically used for debugging and not recommended for
      programmatic access.
    * `prefix` - (optional) [Note: Availability may depend on Kubernetes
      version] If true, adds the container name as a prefix to each line. Useful
      when requesting logs for multiple containers.
  """
  @spec log(
          Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          stream_to :: {Process.dest(), reference()} | Process.dest(),
          opts :: Keyword.t() | nil
        ) ::
          response()
  def log(req, namespace \\ nil, name, stream_to, opts \\ [])

  def log(req, name, stream_to, opts, []) when is_list(opts),
    do: log(req, nil, name, stream_to, opts)

  def log(req, namespace, name, stream_to, opts) do
    options =
      Keyword.merge(opts,
        operation: :connect,
        path_params: [namespace: namespace, name: name],
        into: stream_to,
        subresource: "log"
      )

    Req.request(req, options)
  end

  @doc """

  Opens a websocket to the given Pod and executes a command on it. Can be used
  to open a shell.

  ## Examples

      iex> ref = make_ref()
      ...> res =
      ...>   Req.new()
      ...>   |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      ...>   |> Kubereq.exec("default", "my-pod", {self(), ref},
              params: %{
                "command" => "/bin/bash"
                "tty" => true,
                "stdin" => true,
                "stdout" => true,
                "stderr" => true,
              }

  Messages are sent to the passed Process with the reference included:

      iex> receive(do: ({^ref, message} -> IO.inspect(message)))

  The `body` of the `Req.Response` is a struct. If `tty` is set to true and
  `command` is a shell, you can pass to
  `Kubereq.Websocket.Response.send_message/3` in order to send instructions
  through the websocket to the shell.

      ...> res.body.()

  ## Options

  * `:params` - Map defining the query parameteres added to the request to the
    `pods/exec` subresource. The `exec` subresource supports the following
    paremeters:

    * `container` (optional) - Specifies the container in the pod to execute the
      command. If omitted, the first container in the pod will be chosen.
    * `command` (optional) - The command to execute inside the container. This
      parameter can be specified multiple times to represent a command with
      multiple arguments. If omitted, the container's default command will be
      used.
    * `stdin` (optional) - If true, pass stdin to the container. Default is
      false.
    * `stdout` (optional) - If true, return stdout from the container. Default
      is false.
    * `stderr` (optional) - If true, return stderr from the container. Default
      is false.
    * `tty` (optional) - If true, allocate a pseudo-TTY for the container.
      Default is false.
  """
  @spec exec(
          Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          stream_to :: {Process.dest(), reference()} | Process.dest(),
          opts :: Keyword.t() | nil
        ) ::
          response()
  def exec(req, namespace \\ nil, name, stream_to, opts \\ [])

  def exec(req, name, stream_to, opts, []) when is_list(opts),
    do: exec(req, nil, name, stream_to, opts)

  def exec(req, namespace, name, stream_to, opts) do
    options =
      Keyword.merge(opts,
        operation: :connect,
        path_params: [namespace: namespace, name: name],
        into: stream_to,
        subresource: "exec"
      )

    Req.request(req, options)
  end
end
