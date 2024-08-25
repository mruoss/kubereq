defmodule Kubereq.Kubeconfig.ServiceAccount do
  @moduledoc """
  Pluggable step that builds the Kubeconfig using a Service Account's token for
  authentication.

  When running the app inside a Kubernetes cluster, make sure RBAC is configured
  correctly and use this step. It reads the service account's JWC token and
  build the Kubeconfig accordingly.

  ### Examples

      step Kubereq.Kubeconfig.ServiceAccount

  If your token is mounted at a different location than the default, pass its
  location as `:path_to_folder`.

      step Kubereq.Kubeconfig.ServiceAccount, path_to_folder: "path/to/folder/with/token"

  ### Options

  * `path_to_folder` - (optional) Path to the folder where the `token`, `ca.crt`
    and `namespace` files of the service account are located. Defaults to
    `"/var/run/secrets/kubernetes.io/serviceaccount"`
  * `:!` - (optional. And yes, that's a valid atom) Raise an exception if the
    config file is not found. Defaults to `false`.
  """

  alias Kubeconf

  @behaviour Pluggable

  @sa_token_path "/var/run/secrets/kubernetes.io/serviceaccount"

  @impl true
  @spec init(keyword()) :: keyword()
  def init(opts \\ []) do
    Keyword.validate!(opts, [:path_to_folder, :!])
  end

  @impl true
  @spec call(Kubereq.Kubeconfig.t(), keyword()) :: Kubereq.Kubeconfig.t()
  def call(kubeconf, opts) do
    path_to_folder = opts[:path_to_folder] || @sa_token_path
    apiserver_host = System.get_env("KUBERNETES_SERVICE_HOST")
    apiserver_port = System.get_env("KUBERNETES_SERVICE_PORT_HTTPS")

    files = ["token", "ca.crt", "namespace"] |> Enum.map(&Path.join(path_to_folder, &1))

    raise? = Keyword.get(opts, :!, false)

    case Enum.all?(files, &File.exists?/1) do
      false when raise? ->
        raise ArgumentError, "Could not find all required files: #{inspect(files)}."

      false ->
        kubeconf

      true ->
        [token_file, ca_file, namespace_file] = files

        cluster = %{
          "name" => "default",
          "cluster" => %{
            "certificate-authority" => ca_file,
            "server" => "https://#{apiserver_host}:#{apiserver_port}"
          }
        }

        user = %{
          "name" => "default",
          "user" => %{"tokenFile" => token_file}
        }

        context = %{
          "name" => "default",
          "context" => %{
            "cluster" => cluster["name"],
            "user" => user["name"],
            "namespace" => File.read!(namespace_file)
          }
        }

        Kubereq.Kubeconfig.new!(clusters: [cluster], users: [user], contexts: [context])
        |> Kubereq.Kubeconfig.set_current_context(context["name"])
        |> Pluggable.Token.halt()
    end
  end
end
