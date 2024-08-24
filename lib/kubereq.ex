defmodule Kubereq do
  @moduledoc ~S"""
  Kubereq defines a set of Request Steps for `Req`. All steps combined turn
  a Kubernetes configuration in the form of a `%Kubereq.Kubeconfig{}` struct into a
  `%Req.Request{}` struct containing all headers and options required to
  connect to the cluster and perform the given operations.

  In order to build `%Kubereq.Kubeconfig{}` struct you can either use the steps defined
  in the `Kubeconf` library or create your own Kubernetes configuration loader
  module combining those steps.

  Instead of using this module directly, consider using
  [`Kubegen`](https://github.com/mruoss/kubegen) to generate your API clients.

  ### Examples

  The following is a simple but incomplete example for a Client dealing
  with ConfigMaps. This code is an extraction of what is generated by
  [`Kubegen`](https://github.com/mruoss/kubegen) when generating a client for
  ConfigMaps.

      defmodule MyApp.K8sClient.Core.V1.ConfigMap do
        @resource_path "api/v1/namespaces/:namespace/configmaps/:name"

        defp req() do
          kubeconfig = Kubereq.Kubeconfig.load(Kubereq.Kubeconfig.Default)
          Kubereq.new(kubeconfig, @resource_path)
        end

        def get(namespace, name) do
          Kubereq.get(req(), namespace, name)
        end

        def list(namespace, opts \\ []) do
          Kubereq.list(req(), namespace, opts)
        end
      end
  """
  alias Kubereq.Step

  @type wait_until_callback :: (map() | :deleted -> boolean | {:error, any})
  @type wait_until_response :: :ok | {:error, :watch_timeout}
  @type response() :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  @type namespace :: String.t() | nil
  @type watch_response :: {:ok, Enumerable.t(map())} | {:ok, Task.t()} | {:error, Exception.t()}

  @typep do_watch_response :: {:ok, Enumerable.t(map())} | {:error, Exception.t()}
  @doc """
  Prepares a `Req.Request` struct for making HTTP requests to a Kubernetes
  cluster. The `kubeconfig` is the Kubernetes configuration in the form of a
  `%Kubereq.Kubeconfig{}` struct and should contain all informations required to connect
  to the Kubernetes cluster.

  ### Examples

      iex> kubeconfig = Kubereq.Kubeconfig.load(Kubereq.Kubeconfig.Default)
      ...> Kubereq.new(kubeconfig)
      %Request.Req{...}
  """
  @spec new(kubeconfig :: Kubereq.Kubeconfig.t()) ::
          Req.Request.t()
  def new(kubeconfig) do
    Req.new()
    |> Req.Request.register_options([:kubeconfig, :resource_path, :resource_list_path])
    |> Step.FieldSelector.attach()
    |> Step.LabelSelector.attach()
    |> Step.Compression.attach()
    |> Step.TLS.attach()
    |> Step.Auth.attach()
    |> Step.Impersonate.attach()
    |> Step.BaseUrl.attach()
    |> Req.merge(kubeconfig: kubeconfig)
  end

  @doc """
  Prepares a `Req.Request` struct for a specific resource on a specific
  Kubernetes cluster. The `kubeconfig` is the Kubernetes configuration in the
  form of a `%Kubereq.Kubeconfig{}` struct and should contain all informations required to
  connect to the Kubernetes cluster.

  The parameter `resource_path` should be the path on which the Kubernetes API
  Server listens for requests for the targeted resource kind. It should
  contain placeholders for `:namespace` and `:name`.

  The `:namespace` and `:name` are provided through the `:path_params` option
  built into `Req` when making the request.

  ### Examples

  Prepare a `Req.Request` for ConfigMaps:

      iex> kubeconfig = Kubereq.Kubeconfig.load(Kubereq.Kubeconfig.Default)
      ...> Kubereq.new(kubeconfig, "api/v1/namespaces/:namespace/configmaps/:name")
      %Request.Req{...}
  """
  @spec new(kubeconfig :: Kubereq.Kubeconfig.t(), resource_path :: binary()) ::
          Req.Request.t()
  def new(kubeconfig, resource_path) do
    new(kubeconfig)
    |> Req.merge(
      resource_path: resource_path,
      resource_list_path: String.replace_suffix(resource_path, "/:name", "")
    )
  end

  @doc """
  Create the `resource` object.
  The `req` struct should have been created using `Kubereq.new/2`.

  ### Example

      iex> Kubereq.Client.create(req, resource)
      {:ok, %Req.Response{status: 201, body: %{...}}}
  """
  @spec create(Req.Request.t(), resource :: map()) :: response()
  def create(req, resource) do
    Req.post(req,
      url: req.options.resource_list_path,
      json: resource,
      path_params: [namespace: get_in(resource, ~w(metadata namespace))]
    )
  end

  @doc """
  Get the resource `name` in `namespace`.
  The `req` struct should have been created using `Kubereq.new/2`.

  ### Example

      iex> Kubereq.Client.get(req, "default", "foo")
      {:ok, %Req.Response{status: 200, body: %{...}}}
  """
  @spec get(Req.Request.t(), namespace :: namespace(), name :: String.t()) ::
          response()
  def get(req, namespace, name) do
    Req.get(req, url: req.options.resource_path, path_params: [namespace: namespace, name: name])
  end

  @doc """
  Get a resource list.
  The `req` struct should have been created using `Kubereq.new/2`.

  ### Examples

      iex> Kubereq.Client.list(req, "api/v1/namespaces/:namespace/configmaps", "default", [])
      {:ok, %Req.Response{status: 200, body: %{...}}}

  ### Options

  * `:field_selectors` - A list of field selectors. See `Kubereq.Step.FieldSelector` for more infos.
  * `:label_selectors` - A list of field selectors. See `Kubereq.Step.LabelSelector` for more infos.
  """
  @spec list(Req.Request.t(), namespace :: namespace(), opts :: keyword()) ::
          response()
  def list(req, namespace, opts \\ []) do
    Req.get(req,
      url: req.options.resource_list_path,
      field_selectors: opts[:field_selectors],
      label_selectors: opts[:label_selectors],
      path_params: [namespace: namespace]
    )
  end

  @doc """
  Deletes a resource.
  The `req` struct should have been created using `Kubereq.new/2`.

  ### Examples

      iex> Kubereq.Client.delete(req, "default", "foo")
      {:ok, %Req.Response{status: 200, body: %{...}}}
  """
  @spec delete(Req.Request.t(), namespace :: namespace(), name :: String.t()) ::
          response()
  def delete(req, namespace, name) do
    Req.delete(req,
      url: req.options.resource_path,
      path_params: [namespace: namespace, name: name]
    )
  end

  @doc """
  Deletes all resources in the given namespace.
  The `req` struct should have been created using `Kubereq.new/2`.

  ### Examples

      iex> Kubereq.Client.delete_all(req, "default", "foo")
      {:ok, %Req.Response{...}

  ### Options

  * `:field_selectors` - A list of field selectors. See `Kubereq.Step.FieldSelector` for more infos.
  * `:label_selectors` - A list of field selectors. See `Kubereq.Step.LabelSelector` for more infos.
  """
  @spec delete_all(Req.Request.t(), namespace :: namespace(), opts :: keyword()) :: response()
  def delete_all(req, namespace, opts \\ []) do
    Req.delete(req,
      url: req.options.resource_list_path,
      field_selectors: opts[:field_selectors],
      label_selectors: opts[:label_selectors],
      path_params: [namespace: namespace]
    )
  end

  @doc """
  Updates the given `resource`.
  The `req` struct should have been created using `Kubereq.new/2`.

  ### Examples

      iex> Kubereq.Client.update(req, %{...})
      {:ok, %Req.Response{...}
  """
  @spec update(Req.Request.t(), resource :: map()) :: response()
  def update(req, resource) do
    Req.put(req,
      url: req.options.resource_path,
      json: resource,
      path_params: [
        namespace: get_in(resource, ~w(metadata namespace)),
        name: get_in(resource, ~w(metadata name))
      ]
    )
  end

  @doc """
  Applies the given `resource` using a Server-Side-Apply Patch.
  The `req` struct should have been created using `Kubereq.new/2`.

  See the [documentation](https://kubernetes.io/docs/reference/using-api/server-side-apply/)
  for a documentation on `field_manager` and `force` arguments.

  ### Examples

      iex> Kubereq.Client.apply(req, %{...})
      {:ok, %Req.Response{...}
  """
  @spec apply(Req.Request.t(), resource :: map(), field_manager :: binary(), force :: boolean()) ::
          response()
  def apply(req, resource, field_manager \\ "Elixir", force \\ true) do
    Req.patch(req,
      url: req.options.resource_path,
      path_params: [
        namespace: get_in(resource, ~w(metadata namespace)),
        name: get_in(resource, ~w(metadata name))
      ],
      headers: [{"Content-Type", "application/apply-patch+yaml"}],
      params: [fieldManager: field_manager, force: force],
      json: resource
    )
  end

  @doc """
  Patches the resource `name`in `namespace` using the given `json_patch`.
  The `req` struct should have been created using `Kubereq.new/2`.

  ### Examples

      iex> Kubereq.Client.json_patch(req, %{...}, "default", "foo")
      {:ok, %Req.Response{...}
  """
  @spec json_patch(
          Req.Request.t(),
          json_patch :: map(),
          namespace :: namespace(),
          name :: String.t()
        ) :: response()
  def json_patch(req, json_patch, namespace, name) do
    Req.patch(req,
      url: req.options.resource_path,
      path_params: [namespace: namespace, name: name],
      headers: [{"Content-Type", "application/json-patch+json"}],
      json: json_patch
    )
  end

  @doc """
  Patches the resource `name`in `namespace` using the given `merge_patch`.
  The `req` struct should have been created using `Kubereq.new/2`.

  ### Examples

      iex> Kubereq.Client.merge_patch(req, %{...}, "default", "foo")
      {:ok, %Req.Response{...}
  """
  @spec merge_patch(
          Req.Request.t(),
          merge_patch :: String.t(),
          namespace :: namespace(),
          name :: String.t()
        ) :: response()
  def merge_patch(req, merge_patch, namespace, name) do
    Req.patch(req,
      url: req.options.resource_path,
      path_params: [namespace: namespace, name: name],
      headers: [{"Content-Type", "application/merge-patch+json"}],
      json: merge_patch
    )
  end

  @doc """
  GET a resource and wait until the given `callback` returns true or the given
  `timeout` (ms) has expired.
  The `req` struct should have been created using `Kubereq.new/2`.

  ### Options

  * `timeout` - Timeout in ms after function terminates with `{:error, :timeout}`
  """
  @spec wait_until(
          Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          callback :: wait_until_callback(),
          timeout :: non_neg_integer()
        ) :: wait_until_response()
  def wait_until(req, namespace, name, callback, timeout \\ 10_000) do
    ref = make_ref()
    opts = [field_selectors: [{"metadata.name", name}], stream_to: {self(), ref}]

    with {:ok, resp} <- list(req, namespace, opts),
         {:init, false} <- {:init, callback.(List.first(resp.body["items"]) || :deleted)} do
      {:ok, watch_task} =
        watch(
          req,
          namespace,
          Keyword.put(opts, :resource_version, resp.body["metadata"]["resourceVersion"])
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
  The `req` struct should have been created using `Kubereq.new/2`.

  ### Examples

      iex> Kubereq.Client.watch(req, "default", [])
      {:ok, #Function<60.48886818/2 in Stream.transform/3>}

  In order to watch events in all namespaces, pass `nil` as namespace:

      iex> Kubereq.Client.watch(req, nil, [])
      {:ok, #Function<60.48886818/2 in Stream.transform/3>}

  ### Options

  * `:resource_version` - If given, starts to stream from the given `resourceVersion` of the resource list. Otherwise starts streaming from HEAD.
  * `:stream_to` - If set to a `pid`, streams events to the given pid. If set to `{pid, ref}`, the messages are in the form `{ref, event}`.
  * `:field_selectors` - A list of field selectors. See `Kubereq.Step.FieldSelector` for more infos.
  * `:label_selectors` - A list of field selectors. See `Kubereq.Step.LabelSelector` for more infos.
  """
  @spec watch(
          Req.Request.t(),
          namespace :: namespace(),
          opts :: keyword()
        ) ::
          watch_response()
  def watch(req, namespace, opts \\ []) do
    resource_version = opts[:resource_version]
    do_watch = fn -> do_watch(req, namespace, resource_version, opts) end

    case opts[:stream_to] do
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
  The `req` struct should have been created using `Kubereq.new/2`.

  ### Examples

      iex> Kubereq.Client.watch_single(req, "default", [])
      {:ok, #Function<60.48886818/2 in Stream.transform/3>}

  In order to watch events in all namespaces, pass `nil` as namespace:

      iex> Kubereq.Client.watch_single(req, nil, [])
      {:ok, #Function<60.48886818/2 in Stream.transform/3>}

  ### Options

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
  def watch_single(req, namespace, name, opts \\ []) do
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
             url: req.options.resource_list_path,
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
end
