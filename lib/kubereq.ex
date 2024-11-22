defmodule Kubereq do
  @moduledoc ~S"""
  A Kubernetes client for Elixir based on `Req`.

  ## Usage

  First, attach `kubereq` to your `Req` request (see `attach/2` for options):

      Req.new() |> Kubereq.attach()

  Now you can use plain Req functionality. However, the functions defined in
  this module make it much easier to perform the most common operation.

  ### Usage with plain Req functionality

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

  ### Kubereq API

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
  Attaches `kubereq` to a `Req.Request` struct for making HTTP requests to a
  Kubernetes cluster. You can optionally pass a Kubernetes configuration or
  pipeline via `kubeconfig` option. If it is omitted, the default config
  `Kubereq.Kubeconfig.Default` is loaded.

  ### Examples

      iex> Req.new() |> Kubereq.attach()
      %Request.Req{...}

  ### Options

  All options (see Options section in module doc) are accepted and merged with
  the given req.
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

  Opens a websocket to the given container and streams logs from it.

  > #### Info {: .tip}
  >
  > This function blocks the process. It should be used to retrieve a finite
  > set of logs from a container. If you want to follow logs, use
  > `Kubereq.PodLogs` combined with the `:follow` options instead.

  ## Examples

      req = Req.new() |> Kubereq.attach()
      {:ok, resp} =
        Kubereq.logs(req, "default", "my-pod",
          container: "main-container",
          tailLines: 5
        )
      Enum.each(resp.body, &IO.inspect/1)

  ## Options

  * `:container` - The container for which to stream logs. Defaults to only
    container if there is one container in the pod. Fails if not defined for
    pods with multiple pods.
  * `:follow` - Follow the log stream of the pod. If this is set to `true`,
    the connection is kept alive which blocks current the process. If you need
    this, you probably want to use `Kubereq.PodLogs` instead. Defaults to
    `false`.
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
  * `:previous` - Return previous t  erminated container logs. Defaults to
    `false`.
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
  """
  @spec logs(
          Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: Keyword.t() | nil
        ) ::
          response()
  def logs(req, namespace, name, opts \\ []) do
    opts =
      opts
      |> Keyword.merge(
        namespace: namespace,
        name: name,
        operation: :connect,
        subresource: "log",
        adapter: &Kubereq.Connect.run(&1)
      )
      |> Kubereq.Connect.args_to_opts()

    Req.request(req, opts)
  end

  @doc ~S"""

  Opens a websocket to the given Pod and executes a command on it.

  > #### Info {: .tip}
  >
  > This function blocks the process. It should be used to execute commands
  > which terminate eventually. To implement a shell with a long running
  > connection, use `Kubereq.PodExec` with `tty: true` instead.

  ## Examples
      {:ok, resp} =
        Kubereq.exec(req, "defaault", "my-pod",
          container: "main-container",
          command: "/bin/sh",
          command: "-c",
          command: "echo foobar",
          stdout: true,
          stderr: true
        )
      Enum.each(resp.body, &IO.inspect/1)
      # {:stdout, ""}
      # {:stdout, "foobar\n"}

  ## Options

  * `:container` (optional) - The container to connect to. Defaults to only
    container if there is one container in the pod. Fails if not defined for
    pods with multiple pods.
  * `:command` - Command is the remote command to execute. Not executed within a shell.
  * `:stdin` (optional) - Redirect the standard input stream of the pod for this call. Defaults to `true`.
  * `:stdin` (optional) - Redirect the standard output stream of the pod for this call. Defaults to `true`.
  * `:stderr` (optional) - Redirect the standard error stream of the pod for this call. Defaults to `true`.
  * `:tty` (optional) - If `true` indicates that a tty will be allocated for the exec call. Defaults to `false`.

  """
  @spec exec(
          req :: Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: Keyword.t() | nil
        ) ::
          response()
  def exec(req, namespace, name, opts \\ []) do
    opts =
      opts
      |> Keyword.merge(
        namespace: namespace,
        name: name,
        operation: :connect,
        subresource: "exec",
        adapter: &Kubereq.Connect.run(&1)
      )
      |> Kubereq.Connect.args_to_opts()

    Req.request(req, opts)
  end
end
