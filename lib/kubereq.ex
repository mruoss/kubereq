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

      Req.new() |> Kubereq.attach()

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
  Checks whether the authenticated user is authorized to perform a specific
  action.

  Creates a [SelfSubjectAccessReview][SelfSubjectAccessReview] resource with
  the given `attributes` and sends it to the API Server. It returns
  `.status.allowed` from the result (boolean). In case of an error, the
  function returns `false`.

  ### Attributes

  `attributes` is a Keyword list that allows the following keywords (See
  attribute descriptions on the  [Kubernetes documentation][SelfSubjectAccessReview])

  [SelfSubjectAccessReview]: https://kubernetes.io/docs/reference/kubernetes-api/authorization-resources/self-subject-access-review-v1/

  ### Examples

  Check for a specific action (`GET`) on a specific resource (`pods` in namespace
  `default`):

      Req.new()
      |> Kubereq.attach()
      |> Kubereq.can_i?(verb: "get", version: "v1", resource: "pods", namespace: "default")

  Check for a specific path on the API Server:

      Req.new()
      |> Kubereq.attach()
      |> Kubereq.can_i?(verb: "get", path: "apis/apiregistration.k8s.io/v1")

  """
  @spec can_i?(Req.Request.t(), Keyword.t(), Keyword.t()) :: boolean()
  def can_i?(req, attributes, opts \\ []) do
    spec =
      if attributes[:path] do
        non_resource_attributes =
          attributes
          |> Keyword.validate!([:verb, :path])
          |> Enum.into(%{})

        %{"resourceAttributes" => non_resource_attributes}
      else
        resource_attributes =
          attributes
          |> Keyword.validate!([
            :name,
            :namespace,
            :resource,
            :subresource,
            :fieldSelector,
            :labelSelector,
            :verb,
            :version,
            :group
          ])
          |> Enum.into(%{})

        %{"resourceAttributes" => resource_attributes}
      end

    access_review = %{
      "apiVersion" => "authorization.k8s.io/v1",
      "kind" => "SelfSubjectAccessReview",
      "spec" => spec
    }

    case create(req, access_review, opts) do
      {:ok, %Req.Response{status: 201, body: body}} ->
        body["status"]["allowed"] == true

      _other ->
        false
    end
  end

  @doc """
  Create the `resource` or its `subresource` on the cluster and returns a
  response or an error.

  ### Example

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.create(resource)
  """
  @spec create(Req.Request.t(), resource :: map(), opts :: Keyword.t()) :: response()
  def create(req, resource, opts \\ []) do
    do_create(req, resource, opts, &Req.request/2)
  end

  @doc """
  Create the `resource` or its `subresource` on the cluster and returns a
  response or raises an error.

  ### Example

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.create!(resource)
  """
  @spec create!(Req.Request.t(), resource :: map(), opts :: Keyword.t()) :: Req.Response.t()
  def create!(req, resource, opts \\ []) do
    do_create(req, resource, opts, &Req.request!/2)
  end

  defp do_create(req, resource, opts, request_function) do
    options =
      Keyword.merge(opts,
        operation: :create,
        json: resource,
        path_params: [
          namespace: resource["metadata"]["namespace"],
          name: resource["metadata"]["name"]
        ],
        api_version: resource["apiVersion"],
        kind: resource["kind"]
      )

    request_function.(req, options)
  end

  @doc """
  Get the resource `name` in `namespace` or its `subresource`. and returns a
  response or an error

  Omit `namespace` to get cluster resources.

  ### Example

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.get("default", "foo")
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
    do_get(req, namespace, name, opts, &Req.request/2)
  end

  @doc """
  Get the resource `name` in `namespace` or its `subresource`. and returns a
  response or raises an error

  Omit `namespace` to get cluster resources.

  ### Example

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.get!("default", "foo")
  """
  @spec get!(
          Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: Keyword.t() | nil
        ) ::
          Req.Response.t()
  def get!(req, namespace \\ nil, name, opts \\ [])

  def get!(req, name, opts, []) when is_list(opts), do: get!(req, nil, name, opts)

  def get!(req, namespace, name, opts) do
    do_get(req, namespace, name, opts, &Req.request!/2)
  end

  defp do_get(req, namespace, name, opts, request_function) do
    options =
      Keyword.merge(opts, operation: :get, path_params: [namespace: namespace, name: name])

    request_function.(req, options)
  end

  @doc """
  Get a resource list. Returns a response or an error.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.list("default")

  ### Options

  All options described in the moduledoc plus:

    * `:into` - Optional. When set to `:stream`, the underlying list request to
      Kubernetes is paginated using `:limit` and `:continue` query parameters.

    * `:limit` - Optional. Used with `into: :stream`; defines the limit query
      parameter used for pagination.

  ### Async Response through the `into: :stream`

  With `into: :srteam`, the response's `:body` is a `Stream`

      {:ok, resp} =
        Req.new()
        |> Kubereq.attach(api_version: "v1", kind: "Pod")
        |> Kubereq.list(into: :stream)
      resp.body |> Stream.take(25) |> Enum.to_list()
  """
  @spec list(Req.Request.t(), namespace :: namespace(), opts :: keyword()) :: response()
  def list(req, namespace \\ nil, opts \\ [])

  def list(req, opts, []) when is_list(opts), do: list(req, nil, opts)

  def list(req, namespace, opts) do
    do_list(req, namespace, opts, &Req.request/2)
  end

  @doc """
  Get a resource list. Returns a response or raises an error.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.list!("default")

  ### Options

  All options described in the moduledoc plus:

    * `:into` - Optional. When set to `:stream`, the underlying list request to
      Kubernetes is paginated using `:limit` and `:continue` query parameters.

    * `:limit` - Optional. Used with `into: :stream`; defines the limit query
      parameter used for pagination.

  ### Async Response through the `into: :stream`

  With `into: :srteam`, the response's `:body` is a `Stream`

      {:ok, resp} =
        Req.new()
        |> Kubereq.attach(api_version: "v1", kind: "Pod")
        |> Kubereq.list!(into: :stream)
      resp.body |> Stream.take(25) |> Enum.to_list()
  """
  @spec list!(Req.Request.t(), namespace :: namespace(), opts :: keyword()) :: Req.Response.t()
  def list!(req, namespace \\ nil, opts \\ [])

  def list!(req, opts, []) when is_list(opts), do: list!(req, nil, opts)

  def list!(req, namespace, opts) do
    do_list(req, namespace, opts, &Req.request!/2)
  end

  defp do_list(req, namespace, opts, request_function) do
    case Keyword.pop(opts, :into) do
      {nil, opts} ->
        do_list_single_request(req, namespace, opts, request_function)

      {:stream, opts} ->
        do_list_into_stream(req, namespace, opts, request_function)
    end
  end

  defp do_list_single_request(req, namespace, opts, request_function) do
    options =
      Keyword.merge(opts,
        operation: :list,
        field_selectors: opts[:field_selectors],
        label_selectors: opts[:label_selectors],
        path_params: [namespace: namespace]
      )

    request_function.(req, options)
  end

  defp do_list_into_stream(req, namespace, opts, request_function) do
    params = opts[:params] || []
    params = Keyword.put_new(params, :limit, 10)

    get_items = fn continue ->
      params = Keyword.put(params, :continue, continue)
      opts = Keyword.put(opts, :params, params)
      do_list(req, namespace, opts, request_function)
    end

    with {:ok, %{status: 200, body: body} = resp} <- get_items.(nil) do
      stream = Kubereq.Stream.create_list_stream(body, get_items)
      {:ok, %{resp | body: stream}}
    end
  end

  @doc """
  Deletes the `resource` or its `subresource` from the cluster. Returns a
  response or an error.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.delete("default", "foo")
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
    do_delete(req, namespace, name, opts, &Req.request/2)
  end

  @doc """
  Deletes the `resource` or its `subresource` from the cluster. Returns a
  response or raises an error.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.delete!("default", "foo")
  """
  @spec delete!(
          Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: Keyword.t()
        ) ::
          Req.Response.t()
  def delete!(req, namespace \\ nil, name, opts \\ [])

  def delete!(req, name, opts, []) when is_list(opts), do: delete!(req, nil, name, opts)

  def delete!(req, namespace, name, opts) do
    do_delete(req, namespace, name, opts, &Req.request!/2)
  end

  defp do_delete(req, namespace, name, opts, request_function) do
    options =
      Keyword.merge(opts, operation: :delete, path_params: [namespace: namespace, name: name])

    request_function.(req, options)
  end

  @doc """
  Deletes all resources in the given namespace. Returns a response or an error.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.delete_all("default", label_selectors: [{"app", "my-app"}])
  """
  @spec delete_all(Req.Request.t(), namespace :: namespace(), opts :: keyword()) :: response()
  def delete_all(req, namespace \\ nil, opts \\ [])

  def delete_all(req, opts, []) when is_list(opts), do: delete_all(req, nil, opts)

  def delete_all(req, namespace, opts) do
    do_delete_all(req, namespace, opts, &Req.request/2)
  end

  @doc """
  Deletes all resources in the given namespace. Returns a response or raises an
  error.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.delete_all!("default", label_selectors: [{"app", "my-app"}])
  """
  @spec delete_all!(Req.Request.t(), namespace :: namespace(), opts :: keyword()) ::
          Req.Response.t()
  def delete_all!(req, namespace \\ nil, opts \\ [])

  def delete_all!(req, opts, []) when is_list(opts), do: delete_all!(req, nil, opts)

  def delete_all!(req, namespace, opts) do
    do_delete_all(req, namespace, opts, &Req.request!/2)
  end

  defp do_delete_all(req, namespace, opts, request_function) do
    options = Keyword.merge(opts, operation: :delete_all, path_params: [namespace: namespace])
    request_function.(req, options)
  end

  @doc """
  Updates the given `resource`. Returns a response or an error.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.update(resource)
  """
  @spec update(Req.Request.t(), resource :: map(), opts :: Keyword.t()) :: response()
  def update(req, resource, opts \\ []) do
    do_update(req, resource, opts, &Req.request/2)
  end

  @doc """
  Updates the given `resource`. Returns a response or raises an error.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.update!(resource)
  """
  @spec update!(Req.Request.t(), resource :: map(), opts :: Keyword.t()) :: Req.Response.t()
  def update!(req, resource, opts \\ []) do
    do_update(req, resource, opts, &Req.request!/2)
  end

  defp do_update(req, resource, opts, request_function) do
    options =
      Keyword.merge(opts,
        operation: :update,
        json: resource,
        path_params: [
          namespace: get_in(resource, ~w(metadata namespace)),
          name: get_in(resource, ~w(metadata name))
        ],
        api_version: resource["apiVersion"],
        kind: resource["kind"]
      )

    request_function.(req, options)
  end

  @doc """
  Applies the given `resource` using a Server-Side-Apply Patch. Returns a
  response or an error.

  See the [documentation](https://kubernetes.io/docs/reference/using-api/server-side-apply/)
  for a documentation on `field_manager` and `force` arguments.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.apply(resource)
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
    do_apply(req, resource, field_manager, force, opts, &Req.request/2)
  end

  @doc """
  Applies the given `resource` using a Server-Side-Apply Patch. Returns a
  response or raises an error.

  See the [documentation](https://kubernetes.io/docs/reference/using-api/server-side-apply/)
  for a documentation on `field_manager` and `force` arguments.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.apply!(resource)
  """
  @spec apply!(
          Req.Request.t(),
          resource :: map(),
          field_manager :: binary(),
          force :: boolean(),
          opts :: Keyword.t()
        ) :: Req.Response.t()
  def apply!(req, resource, field_manager \\ "Elixir", force \\ true, opts \\ [])

  def apply!(req, resource, opts, _, _) when is_list(opts) do
    apply!(req, resource, "Elixir", true, opts)
  end

  def apply!(req, resource, field_manager, force, opts) do
    do_apply(req, resource, field_manager, force, opts, &Req.request!/2)
  end

  defp do_apply(req, resource, field_manager, force, opts, request_function) do
    options =
      Keyword.merge(opts,
        operation: :apply,
        path_params: [
          namespace: get_in(resource, ~w(metadata namespace)),
          name: get_in(resource, ~w(metadata name))
        ],
        params: [fieldManager: field_manager, force: force],
        json: resource,
        api_version: resource["apiVersion"],
        kind: resource["kind"]
      )

    request_function.(req, options)
  end

  @doc """
  Patches the resource `name`in `namespace` or its `subresource` using the given
  `json_patch`. Returns a response or an error.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.json_patch(%{...}, "default", "foo")
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
    do_json_patch(req, json_patch, namespace, name, opts, &Req.request/2)
  end

  @doc """
  Patches the resource `name`in `namespace` or its `subresource` using the given
  `json_patch`. Returns a response or raises an error.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.json_patch!(%{...}, "default", "foo")
  """
  @spec json_patch!(
          Req.Request.t(),
          json_patch :: map(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: Keyword.t()
        ) :: Req.Response.t()
  def json_patch!(req, json_patch, namespace \\ nil, name, opts \\ [])

  def json_patch!(req, json_patch, name, opts, []) when is_list(opts) do
    json_patch!(req, json_patch, nil, name, opts)
  end

  def json_patch!(req, json_patch, namespace, name, opts) do
    do_json_patch(req, json_patch, namespace, name, opts, &Req.request!/2)
  end

  defp do_json_patch(req, json_patch, namespace, name, opts, request_function) do
    options =
      Keyword.merge(opts,
        operation: :json_patch,
        path_params: [namespace: namespace, name: name],
        json: json_patch
      )

    request_function.(req, options)
  end

  @doc """
  Patches the resource `name`in `namespace` or its `subresource` using the given
  `merge_patch`. Returns a response or an error.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.merge_patch(%{...}, "default", "foo")
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
    do_merge_patch(req, merge_patch, namespace, name, opts, &Req.request/2)
  end

  @doc """
  Patches the resource `name`in `namespace` or its `subresource` using the given
  `merge_patch`. Returns a response or raises an error.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.merge_patch!(%{...}, "default", "foo")
  """
  @spec merge_patch!(
          Req.Request.t(),
          merge_patch :: String.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: Keyword.t()
        ) :: Req.Response.t()
  def merge_patch!(req, merge_patch, namespace \\ nil, name, opts \\ [])

  def merge_patch!(req, merge_patch, name, opts, []) when is_list(opts) do
    merge_patch!(req, merge_patch, nil, name, opts)
  end

  def merge_patch!(req, merge_patch, namespace, name, opts) do
    do_merge_patch(req, merge_patch, namespace, name, opts, &Req.request!/2)
  end

  defp do_merge_patch(req, merge_patch, namespace, name, opts, request_function) do
    options =
      Keyword.merge(opts,
        operation: :merge_patch,
        path_params: [namespace: namespace, name: name],
        json: merge_patch
      )

    request_function.(req, options)
  end

  @doc """
  GET a resource and wait until the given `callback` returns true or the given
  `timeout` (ms) has expired.

  ### Options

  All options described in the moduledoc plus:

  * `:timeout` - Timeout in ms after function terminates with `{:error, :timeout}`
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
    opts = Keyword.put(opts, :field_selectors, [{"metadata.name", name}])

    with {:ok, resp} <- list(req, namespace, opts),
         {:init, false} <- {:init, callback.(List.first(resp.body["items"]) || :deleted)} do
      {:ok, resp} =
        req
        |> Req.merge(opts)
        |> watch(namespace,
          resource_version: resp.body["metadata"]["resourceVersion"],
          receive_timeout: timeout
        )

      wait_event_loop(resp.body, callback)
    else
      {:init, true} -> :ok
      {:init, {:error, error}} -> {:error, error}
      {:error, error} -> {:error, error}
    end
  end

  defp wait_event_loop(stream, callback) do
    stream
    |> Enum.reduce_while(nil, fn
      %{"type" => "DELETED"}, _acc ->
        case callback.(:deleted) do
          true -> {:halt, :ok}
          false -> {:halt, :ok}
          :ok -> {:halt, :ok}
          {:error, error} -> {:halt, {:error, error}}
        end

      %{"object" => resource}, _acc ->
        if callback.(resource), do: {:halt, :ok}, else: {:cont, nil}
    end)
  rescue
    e in Mint.TransportError ->
      if e.reason == :timeout do
        {:error, :watch_timeout}
      else
        reraise e, __STACKTRACE__
      end
  end

  @doc """
  Watch events of all resources in `namespace`. If `namespace` is `nil`, all
  namespaces are watched. Returns a response or an error.

  > #### Info {: .tip}
  >
  > The Enumerable returned via the response's body blocks the process when run.
  > Use `Kubereq.Watcher` instead if you want to build a long running process
  > handling all occurring events.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.watch("default")

  Omit the `namespace` in order to watch events in all namespaces:

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.watch()

  ### Options

    All options described in the moduledoc plus:

      * `:resource_version` - Optional. Resource version to start watching from.
        Per default, the watcher starts watching from the current
        resource_version.
  """
  @spec watch(
          Req.Request.t(),
          namespace :: namespace(),
          opts :: keyword()
        ) :: response()
  def watch(req, namespace \\ nil, opts \\ [])

  def watch(req, opts, []) when is_list(opts) do
    watch(req, nil, opts)
  end

  def watch(req, namespace, opts) do
    with {:ok, %{status: 200, body: body} = resp} <-
           Kubereq.Watcher.connect(req, namespace, opts) do
      stream = Kubereq.Watcher.transform_to_objects(body)

      {:ok, %{resp | body: stream}}
    end
  end

  @doc """
  Watch events of all resources in `namespace`. If `namespace` is `nil`, all
  namespaces are watched. Returns a response or raises an error.

  > #### Info {: .tip}
  >
  > The Enumerable returned via the response's body blocks the process when run.
  > Use `Kubereq.Watcher` instead if you want to build a long running process
  > handling all occurring events.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.watch!("default")

  Omit the `namespace` in order to watch events in all namespaces:

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.watch!()

  ### Options

    All options described in the moduledoc plus:

      * `:resource_version` - Optional. Resource version to start watching from.
        Per default, the watcher starts watching from the current
        resource_version.
  """
  @spec watch!(
          Req.Request.t(),
          namespace :: namespace(),
          opts :: keyword()
        ) :: Req.Response.t()
  def watch!(req, namespace \\ nil, opts \\ [])

  def watch!(req, opts, []) when is_list(opts) do
    watch!(req, nil, opts)
  end

  def watch!(req, namespace, opts) do
    case watch(req, namespace, opts) do
      {:ok, resp} -> resp
      {:error, error} -> raise error
    end
  end

  @doc """
  Watch events of a single resources `name`in `namespace`. Returns a response
  or an error.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.watch_single("default")

  Omit the second argument in order to watch events in all namespaces:

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.watch_single()

  """
  @spec watch_single(
          Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: keyword()
        ) :: response()
  def watch_single(req, namespace \\ nil, name, opts \\ [])

  def watch_single(req, name, opts, []) when is_list(opts) do
    watch_single(req, nil, name, opts)
  end

  def watch_single(req, namespace, name, opts) do
    do_watch_single(req, namespace, name, opts, &watch/3)
  end

  @doc """
  Watch events of a single resources `name`in `namespace`. Returns a response
  or raises an error.

  ### Examples

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.watch_single!("default")

  Omit the second argument in order to watch events in all namespaces:

      Req.new()
      |> Kubereq.attach(api_version: "v1", kind: "ConfigMap")
      |> Kubereq.watch_single!()

  """
  @spec watch_single!(
          Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: keyword()
        ) :: Req.Response.t()
  def watch_single!(req, namespace \\ nil, name, opts \\ [])

  def watch_single!(req, name, opts, []) when is_list(opts) do
    watch_single!(req, nil, name, opts)
  end

  def watch_single!(req, namespace, name, opts) do
    do_watch_single(req, namespace, name, opts, &watch!/3)
  end

  defp do_watch_single(req, namespace, name, opts, watch_function) do
    opts = Keyword.put(opts, :field_selectors, [{"metadata.name", name}])
    watch_function.(req, namespace, opts)
  end

  @doc """
  Opens a websocket to the given container and streams logs from it.
  Returns a response or an error.

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
    do_logs(req, namespace, name, opts, &Req.request/2)
  end

  @doc """
  Opens a websocket to the given container and streams logs from it.
  Returns a response or raises an error.

  > #### Info {: .tip}
  >
  > This function blocks the process. It should be used to retrieve a finite
  > set of logs from a container. If you want to follow logs, use
  > `Kubereq.PodLogs` combined with the `:follow` options instead.

  ## Examples

      req = Req.new() |> Kubereq.attach()
      {:ok, resp} =
        Kubereq.logs!(req, "default", "my-pod",
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
  @spec logs!(
          Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: Keyword.t() | nil
        ) ::
          Req.Response.t()
  def logs!(req, namespace, name, opts \\ []) do
    do_logs(req, namespace, name, opts, &Req.request!/2)
  end

  defp do_logs(req, namespace, name, opts, request_function) do
    opts =
      opts
      |> Keyword.merge(
        namespace: namespace,
        name: name,
        operation: :connect,
        subresource: "log",
        adapter: &Kubereq.PodLogs.run(&1)
      )
      |> Kubereq.PodLogs.args_to_opts()

    request_function.(req, opts)
  end

  @doc ~S"""

  Opens a websocket to the given Pod and executes a command on it.
  Returns a response or an error.

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
    do_exec(req, namespace, name, opts, &Req.request/2)
  end

  @doc ~S"""

  Opens a websocket to the given Pod and executes a command on it.
  Returns a response or raises an error.

  > #### Info {: .tip}
  >
  > This function blocks the process. It should be used to execute commands
  > which terminate eventually. To implement a shell with a long running
  > connection, use `Kubereq.PodExec` with `tty: true` instead.

  ## Examples
      {:ok, resp} =
        Kubereq.exec!(req, "defaault", "my-pod",
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
  @spec exec!(
          req :: Req.Request.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: Keyword.t() | nil
        ) ::
          Req.Response.t()
  def exec!(req, namespace, name, opts \\ []) do
    do_exec(req, namespace, name, opts, &Req.request!/2)
  end

  defp do_exec(req, namespace, name, opts, request_function) do
    opts =
      opts
      |> Keyword.merge(
        namespace: namespace,
        name: name,
        operation: :connect,
        subresource: "exec",
        adapter: &Kubereq.PodExec.run(&1)
      )
      |> Kubereq.PodExec.args_to_opts()

    request_function.(req, opts)
  end
end
