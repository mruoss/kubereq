defmodule Kubereq.Kubeconfig.Stub do
  @moduledoc """
  Req testing conveniences for `kubereq` requests.

  Since `kubereq` is using `Req` under the hood, we can use
  [`Req.Test`](https://hexdocs.pm/req/Req.Test.html) to run requests through
  mocks/stubs. Using this step as your Kubeconfig pipeline, you can set a stub
  on the `Req.Request` configured by this step.

  In your tests, you can then use `Req.Test` according to its documentation.

  ## Example

  Imagine we're building an app with a pod client that lists pods on the
  cluster.

  We start off by defining a module for loading the Kubernetes config:

      defmodule MyApp.Kubeconfig do
        @kubeconfig_pipeline Application.compile_env(:myapp, :kubeconfig_pipeline)

        def load(), do: Kubereq.Kubeconfig.load(@kubeconfig_pipeline)
      end

  We then implement the pod client using the Kubeconfig loader to create a
  `Req.Request`:

      defmodule MyApp.PodClient do
        @resource_path "api/v1/namespaces/:namespace/pods/:name"

        def list(namespace) do
          req = Kubereq.new(MyApp.Kubeconfig.load(), @resource_path)

          {:ok, resp} = Kubereq.list(req, namespace)
          resp.body["items"]
        end
      end

  We configure the kubeconfig pipeline for production using
  `Kubereq.Kubeconfig.Default` as our pipeline to load the Kubeconfig:

      # config/prod.exs
      config :myapp, kubeconfig_pipeline: Kubereq.Kubeconfig.Default

  In tests, instead of sending requests to the cluster, we make the request
  against a plug stub named `MyApp.Cluster`:

      # config/test.exs
      config :myapp, kubeconfig_pipeline: {Kubereq.Kubeconfig.Stub, plugs: {Req.Test, MyApp.Cluster}}

  Now we can control our stubs in concurrent tests:

      use ExUnit.Case, async: true

      test "many pods" do
        Req.Test.stub(MyApp.Cluster, fn conn ->
          Req.Test.json(conn, %{
            "apiVersion" => "v1",
            "kind" => "List",
            "items" => [
              %{
                "apiVersion" => "v1",
                "kind" => "Pod"
                # ...
              }
            ]
          })
        end)

        assert [_] = MyApp.PodClient.list("default")
      end

  ## Stubs per Context

  If you want to simulate multiple different clusters or different responses for
  the same calls, you can pass a `%{context :: String.t() => plug :: tuple}` map
  to as `plugs` option.

      # config/test.exs
      config :myapp, kubeconfig_pipeline: {Kubereq.Kubeconfig.Stub, plugs: %{
        "happy-path" => {Req.Test, MyApp.HappyPathCluster}
        "missing-permissions" => {Req.Test, MyApp.MissingPermissionsCluster}
      }}

  ## Options

  * `plugs` - The plug or `%{context => plug}` map to be configured on the
    `Req.Request` configured by this step.
  """

  @behaviour Pluggable

  @impl true
  @spec init(keyword()) :: keyword()
  def init(opts \\ []) do
    if !opts[:plugs] do
      raise ArgumentError, "You have to pass the :plugs option to use this step."
    end

    Keyword.validate!(opts, [:plugs])
  end

  @impl true
  @spec call(Kubereq.Kubeconfig.t(), keyword()) :: Kubereq.Kubeconfig.t()
  def call(_kubeconf, opts) do
    user = %{
      "name" => "dummy",
      "user" => %{}
    }

    plugs =
      if is_tuple(opts[:plugs]) do
        %{"default" => opts[:plugs]}
      else
        opts[:plugs]
      end

    {clusters, contexts} =
      for {context_name, plug} <- plugs, reduce: {[], []} do
        {clusters, contexts} ->
          cluster = %{
            "name" => context_name,
            "cluster" => %{"plug" => plug, "server" => "http://stub.local"}
          }

          context = %{
            "name" => context_name,
            "context" => %{
              "cluster" => context_name,
              "user" => "dummy",
              "namespace" => "default"
            }
          }

          {[cluster | clusters], [context | contexts]}
      end

    Kubereq.Kubeconfig.new!(clusters: clusters, users: [user], contexts: contexts)
    |> Kubereq.Kubeconfig.set_current_context(get_in(contexts, [Access.at(0), "name"]))
  end
end
