defmodule Kubereq.Client do
  @moduledoc """
  Kubernetes Client offering functions for Kubernetes operations and using `Req`
  to make the HTTP request.
  """

  alias Kubereq.Client.Watch

  @type wait_until_callback :: (map() | :deleted -> boolean)
  @type name :: String.t()
  @type namespace :: String.t() | nil
  @type watch_response :: {:ok, Enumerable.t(map())} | {:ok, Task.t()} | {:error, Exception.t()}
  @type response() :: {:ok, Req.Response.t()} | {:error, Exception.t()}

  @typep do_watch_response :: {:ok, Enumerable.t(map())} | {:error, Exception.t()}

  @doc """
  Create the `resource` object at the given `path`. The `req` object should
  contain all necessary information to connect to the Kubernetes API Server.

  The Path should contain a placeholder for the `:namespace`. Its value will be
  retrieved from the given `resource`.

  ### Example

      iex> Kubereq.Client.create(req, "api/v1/namespaces/:namespace/configmaps", resource)
      {:ok, %Req.Response{status: 201, body: %{...}}}
  """
  @spec create(Req.Request.t(), path :: String.t(), resource :: map()) :: response()
  def create(req, path, resource) do
    Req.post(req,
      url: path,
      json: resource,
      path_params: [namespace: get_in(resource, ~w(metadata namespace))]
    )
  end

  @doc """
  Get the resource at the given `path`. The `req` object should
  contain all necessary information to connect to the Kubernetes API Server.

  The Path should contain a placeholder for the `:namespace` and `:name`. The
  `namespace` and `name` params will be used to fill them.

  ### Example

      iex> Kubereq.Client.get(req, "api/v1/namespaces/:namespace/configmaps/:name", "default", "foo")
      {:ok, %Req.Response{status: 200, body: %{...}}}
  """
  @spec get(Req.Request.t(), path :: String.t(), namespace :: namespace(), name :: String.t()) ::
          response()
  def get(req, path, namespace, name) do
    Req.get(req, url: path, path_params: [namespace: namespace, name: name])
  end

  @doc """
  Get a the resource list at the given `path`. The `req` object should
  contain all necessary information to connect to the Kubernetes API Server.

  The Path should contain a placeholder for the `:namespace`. The `namespace`
  param will be used to fill it.

  ### Examples

      iex> Kubereq.Client.list(req, "api/v1/namespaces/:namespace/configmaps", "default", [])
      {:ok, %Req.Response{status: 200, body: %{...}}}

  ### Options

  * `:field_selectors` - A list of field selectors. See `Kubereq.Step.FieldSelector` for more infos.
  * `:label_selectors` - A list of field selectors. See `Kubereq.Step.LabelSelector` for more infos.

  """
  @spec list(Req.Request.t(), path :: String.t(), namespace :: namespace(), opts :: keyword()) ::
          response()
  def list(req, path, namespace, opts \\ []) do
    Req.get(req,
      url: path,
      field_selectors: opts[:field_selectors],
      label_selectors: opts[:label_selectors],
      path_params: [namespace: namespace]
    )
  end

  @doc """
  Watch resource events at the given `path`. The `req` object should
  contain all necessary information to connect to the Kubernetes API Server.

  The Path should contain a placeholder for the `:namespace`. The `namespace`
  param will be used to fill it.

  ### Examples

      iex> Kubereq.Client.watch(req, "api/v1/namespaces/:namespace/configmaps", "default", [])
      {:ok, #Function<60.48886818/2 in Stream.transform/3>}

  In order to watch events in all namespaces, pass `nil` as namespace:

      iex> Kubereq.Client.watch(req, "api/v1/namespaces/:namespace/configmaps", nil, [])
      {:ok, #Function<60.48886818/2 in Stream.transform/3>}

  ### Options

  * `:field_selectors` - A list of field selectors. See `Kubereq.Step.FieldSelector` for more infos.
  * `:label_selectors` - A list of field selectors. See `Kubereq.Step.LabelSelector` for more infos.

  """
  @spec watch(Req.Request.t(), path :: String.t(), namespace :: namespace(), opts :: keyword()) ::
          watch_response()
  def watch(req, path, namespace, opts) when is_list(opts) do
    resource_version = opts[:resource_version]
    do_watch = fn -> do_watch(req, path, namespace, resource_version, opts) end

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

  @spec watch(Req.Request.t(), path :: String.t(), namespace :: namespace(), name :: String.t()) ::
          watch_response()
  def watch(req, path, namespace, name) do
    watch(req, path, namespace, name, [])
  end

  @spec watch(
          Req.Request.t(),
          path :: String.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: keyword()
        ) :: watch_response()
  def watch(req, path, namespace, name, opts) do
    opts = Keyword.put(opts, :field_selectors, [{"metadata.name", name}])
    watch(req, path, namespace, opts)
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
          path :: String.t(),
          namespace :: namespace(),
          resource_version :: integer() | String.t(),
          opts :: keyword()
        ) :: do_watch_response()
  defp(do_watch(req, path, namespace, nil, opts)) do
    with {:ok, resp} <- list(req, path, namespace, opts) do
      resource_version = resp.body["metadata"]["resourceVersion"]
      do_watch(req, path, namespace, resource_version, opts)
    end
  end

  defp do_watch(req, path, namespace, resource_version, opts) do
    with {:ok, resp} <-
           Req.get(req,
             url: path,
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
        |> Watch.create_stream()
        |> Watch.transform_to_objects()

      {:ok, stream}
    end
  end

  @spec delete(Req.Request.t(), path :: String.t(), namespace :: namespace(), name :: String.t()) ::
          response()
  def delete(req, path, namespace, name) do
    Req.delete(req, url: path, path_params: [namespace: namespace, name: name])
  end

  @spec delete_all(Req.Request.t(), path :: String.t(), namespace :: namespace()) :: response()
  def delete_all(req, path, namespace) do
    Req.delete(req, url: path, path_params: [namespace: namespace])
  end

  @spec update(Req.Request.t(), path :: String.t(), resource :: map()) :: response()
  def update(req, path, resource) do
    Req.put(req,
      url: path,
      path_params: [
        namespace: get_in(resource, ~w(metadata namespace)),
        name: get_in(resource, ~w(metadata name))
      ]
    )
  end

  def apply(req, path, resource, field_manager \\ "Elixir", force \\ true) do
    Req.patch(req,
      url: path,
      path_params: [
        namespace: get_in(resource, ~w(metadata namespace)),
        name: get_in(resource, ~w(metadata name))
      ],
      headers: [{"Content-Type", "application/apply-patch+yaml"}],
      params: [fieldManager: field_manager, force: force],
      json: resource
    )
  end

  def json_patch(req, path, json_patch, namespace, name) do
    Req.patch(req,
      url: path,
      path_params: [namespace: namespace, name: name],
      headers: [{"Content-Type", "application/json-patch+json"}],
      json: json_patch
    )
  end

  def merge_patch(req, path, merge_patch, namespace, name) do
    Req.patch(req,
      url: path,
      path_params: [namespace: namespace, name: name],
      headers: [{"Content-Type", "application/merge-patch+json"}],
      body: merge_patch
    )
  end

  @doc """
  GET a resource and wait until the given `callback` returns true or the given
  `timeout` (ms) has expired.

  ### Options

  * `timeout` - Timeout in ms after function terminates with `{:error, :timeout}`
  """
  def wait_until(req, path, namespace, name, callback, timeout \\ 10_000) do
    ref = make_ref()
    opts = [field_selectors: [{"metadata.name", name}], stream_to: {self(), ref}]

    with {:ok, list} <- list(req, path, namespace, opts),
         {:init, false} <- {:init, callback.(List.first(list["items"]))} do
      {:ok, watch_task} = watch(req, path, namespace, opts)
      timer = Process.send_after(self(), {ref, :timeout}, timeout)
      result = wait_event_loop(ref, callback)
      Task.shutdown(watch_task)
      Process.cancel_timer(timer)
      result
    else
      {:init, true} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp wait_event_loop(ref, callback) do
    receive do
      {^ref, %{"type" => "DELETED"}} ->
        if callback.(:deleted), do: :ok, else: wait_event_loop(ref, callback)

      {^ref, %{"object" => resource}} ->
        if callback.(resource), do: :ok, else: wait_event_loop(ref, callback)

      {^ref, :timeout} ->
        {:error, :watch_timeout}
    end
  end
end
