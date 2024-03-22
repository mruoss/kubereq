defmodule Kubereq.Client do
  alias Kubereq.Client.Watch

  @type wait_until_callback :: (map() | :deleted -> boolean)
  @type name :: String.t()
  @type namespace :: String.t() | nil
  @type watch_response :: {:ok, Enumerable.t()} | {:ok, Task.t()}
  @type response() :: {:ok, map()}

  @spec resource_path(api_version :: String.t(), resource_definition :: map()) :: String.t()
  def resource_path(<<?v, _::integer>> = api_version, resource_definition) do
    do_resource_path("api/#{api_version}", resource_definition)
  end

  def resource_path(api_version, resource_definition) do
    do_resource_path("apis/#{api_version}", resource_definition)
  end

  @spec do_resource_path(api_version :: String.t(), resource_definition :: map()) :: String.t()
  defp do_resource_path(api_version, %{"name" => resource_name, "namespaced" => true}) do
    "#{api_version}/namespaces/:namespace/#{resource_name}/:name"
  end

  defp do_resource_path(api_version, %{"name" => resource_name, "namespaced" => false}) do
    "#{api_version}/#{resource_name}/:name"
  end

  @spec add_ssl_opts(Req.Request.t(), keyword()) :: Req.Request.t()
  def add_ssl_opts(req, options) do
    connect_options = List.wrap(req.options[:connect_options])
    transport_opts = List.wrap(connect_options[:transport_opts])
    transport_opts = Keyword.merge(transport_opts, options)
    connect_options = Keyword.merge(connect_options, transport_opts: transport_opts)
    Req.merge(req, connect_options: connect_options)
  end

  @spec resource_list_path(api_version :: String.t(), resource_definition :: map()) :: String.t()
  def resource_list_path(<<?v, _::integer>> = api_version, resource_definition) do
    do_resource_list_path("api/#{api_version}", resource_definition)
  end

  def resource_list_path(api_version, resource_definition) do
    do_resource_list_path("apis/#{api_version}", resource_definition)
  end

  @spec do_resource_list_path(api_version :: String.t(), resource_definition :: map()) ::
          String.t()
  defp do_resource_list_path(api_version, %{"name" => resource_name, "namespaced" => true}) do
    "#{api_version}/namespaces/:namespace/#{resource_name}"
  end

  defp do_resource_list_path(api_version, %{"name" => resource_name, "namespaced" => false}) do
    "#{api_version}/#{resource_name}"
  end

  @spec create(Req.Request.t(), path :: String.t(), resource :: map()) :: response()
  def create(req, path, resource) do
    with {:ok, resp} <-
           Req.post(req,
             url: path,
             json: resource,
             path_params: [namespace: get_in(resource, ~w(metadata namespace))]
           ) do
      {:ok, resp.body}
    end
  end

  @spec get(Req.Request.t(), path :: String.t(), namespace :: namespace(), name :: String.t()) ::
          response()
  def get(req, path, namespace, name) do
    with {:ok, resp} <-
           Req.get(req, url: path, path_params: [namespace: namespace, name: name]) do
      {:ok, resp.body}
    end
  end

  @spec list(Req.Request.t(), path :: String.t(), namespace :: namespace(), opts :: keyword()) ::
          response()
  def list(req, path, namespace, opts \\ []) do
    with {:ok, resp} <-
           Req.get(req,
             url: path,
             field_selectors: opts[:field_selectors],
             label_selectors: opts[:label_selectors],
             path_params: [namespace: namespace]
           ) do
      {:ok, resp}
    end
  end

  @spec watch(Req.Request.t(), path :: String.t(), namespace :: namespace(), opts :: keyword()) ::
          watch_response()
  def watch(req, path, namespace, opts) when is_list(opts) do
    resource_version = opts[:resource_version]

    case opts[:stream_to] do
      nil ->
        do_watch(req, path, namespace, resource_version, opts)

      {pid, ref} ->
        task =
          Task.async(fn ->
            case do_watch(req, path, namespace, resource_version, opts) do
              {:ok, stream} ->
                stream
                |> Stream.map(&send(pid, {ref, &1}))
                |> Stream.run()

              {:error, error} ->
                send(pid, {:error, error})
            end
          end)

        {:ok, task}

      pid ->
        task =
          Task.async(fn ->
            case do_watch(req, path, namespace, resource_version, opts) do
              {:ok, stream} ->
                stream
                |> Stream.map(&send(pid, &1))
                |> Stream.run()

              {:error, error} ->
                send(pid, {:error, error})
            end
          end)

        {:ok, task}
    end
  end

  @spec watch(Req.Request.t(), path :: String.t(), namespace :: namespace(), name :: String.t()) ::
          watch_response()
  def watch(req, path, namespace, name) do
    watch(req, path, namespace, name, [])
  end

  @spec watch(
          Req.Requst.t(),
          path :: String.t(),
          namespace :: namespace(),
          name :: String.t(),
          opts :: keyword()
        ) :: {:ok, Enumerable.t(map())}
  def watch(req, path, namespace, name, opts) do
    opts = Keyword.put(opts, :field_selectors, [{"metadata.name", name}])
    watch(req, path, namespace, opts)
  end

  @spec do_watch(
          Req.Requst.t(),
          path :: String.t(),
          namespace :: namespace(),
          resource_version :: integer() | String.t(),
          opts :: keyword()
        ) :: {:ok, Enumerable.t()}
  defp do_watch(req, path, namespace, nil, opts) do
    with {:ok, podlist} <- list(req, path, namespace, opts) do
      resource_version = podlist["metadata"]["resourceVersion"]
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
               {"watch", "1"},
               {"allowWatchBookmarks", "1"},
               {"resourceVersion", resource_version}
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
    with {:ok, resp} <-
           Req.delete(req, url: path, path_params: [namespace: namespace, name: name]) do
      {:ok, resp.body}
    end
  end

  @spec delete_all(Req.Request.t(), path :: String.t(), namespace :: namespace()) :: response()
  def delete_all(req, path, namespace) do
    with {:ok, resp} <-
           Req.delete(req, url: path, path_params: [namespace: namespace]) do
      {:ok, resp.body}
    end
  end

  @spec update(Req.Request.t(), path :: String.t(), resource :: map()) :: response()
  def update(req, path, resource) do
    with {:ok, resp} <-
           Req.put(req,
             url: path,
             path_params: [
               namespace: get_in(resource, ~w(metadata namespace)),
               name: get_in(resource, ~w(metadata name))
             ]
           ) do
      {:ok, resp.body}
    end
  end

  def apply(req, path, resource, field_manager \\ "Elixir", force \\ true) do
    with {:ok, resp} <-
           Req.patch(req,
             url: path,
             path_params: [
               namespace: get_in(resource, ~w(metadata namespace)),
               name: get_in(resource, ~w(metadata name))
             ],
             headers: [{"Content-Type", "application/apply-patch+yaml"}],
             params: [fieldManager: field_manager, force: force],
             json: resource
           ) do
      {:ok, resp.body}
    end
  end

  def json_patch(req, path, json_patch, namespace, name) do
    with {:ok, resp} <-
           Req.patch(req,
             url: path,
             path_params: [namespace: namespace, name: name],
             headers: [{"Content-Type", "application/json-patch+json"}],
             json: json_patch
           ) do
      {:ok, resp.body}
    end
  end

  def merge_patch(req, path, merge_patch, namespace, name) do
    with {:ok, resp} <-
           Req.patch(req,
             url: path,
             path_params: [namespace: namespace, name: name],
             headers: [{"Content-Type", "application/merge-patch+json"}],
             body: merge_patch
           ) do
      {:ok, resp.body}
    end
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
