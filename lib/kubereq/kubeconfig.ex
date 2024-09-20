defmodule Kubereq.Kubeconfig do
  @moduledoc """
  This is the `Pluggable.Token` for the pipeline loading the Kubernetes config.
  """

  alias Kubereq.Access

  @derive Pluggable.Token

  @typedoc """
  The `%Kubereq.Kubeconfig{}` struct holds information required to connect to
  Kubernetes clusters

  For descriptions of the fields, refer to the
  [kubeconfig.v1](https://kubernetes.io/docs/reference/config-api/kubeconfig.v1/) documentation.
  """
  @type t :: %__MODULE__{
          clusters: list(map()),
          users: list(map()),
          contexts: list(map()),
          current_context: String.t(),
          current_cluster: map(),
          current_user: map(),
          halted: boolean(),
          assigns: map()
        }

  defstruct clusters: [],
            users: [],
            contexts: [],
            current_context: nil,
            current_cluster: nil,
            current_user: nil,
            halted: false,
            assigns: %{}

  @doc """
  Creates a new `%Kubereq.Kubeconfig{}` struct with the given fields
  """
  @spec new!(keyword()) :: t()
  def new!(fields), do: struct!(__MODULE__, fields)

  @doc """
  Sets the current context. This function sets `current_cluster` and
  `current_user` in the given `Kubereq.Kubeconfig.t()`
  """
  @spec set_current_context(kubeconfig :: t(), current_context :: String.t()) :: t()
  def set_current_context(kubeconfig, current_context) do
    context =
      get_in(kubeconfig.contexts, [
        access_by_name!(current_context),
        "context"
      ])

    current_cluster =
      get_in(kubeconfig.clusters, [
        access_by_name!(context["cluster"]),
        "cluster"
      ])

    current_user =
      get_in(kubeconfig.users, [
        access_by_name!(context["user"]),
        "user"
      ])

    struct!(kubeconfig,
      current_cluster: current_cluster,
      current_user: current_user,
      current_context: current_context
    )
  end

  @doc """
  Loads the Kubernetes config by running the given `pipeline`. Returns the
  resulting `%Kubereq.Kubeconfig{}`.

  `pipeline` can be passed in the form of `{pipeline_module, opts}` tuples,
  a single `pipeline_module` or a list of either.

  ### Example

  Single pipeline module without opts passed as module:

      Kubereq.Kubeconfig.load(Kubereq.Kubeconfig.Default)

  Single pipeline module with opts:

      Kubereq.Kubeconfig.load({Kubereq.Kubeconfig.File, path: "/path/to/kubeconfig"})

  List of either:

      Kubereq.Kubeconfig.load([
        Kubereq.Kubeconfig.ENV,
        {Kubereq.Kubeconfig.File, path: ".kube/config", relative_to_home?: true},
        Kubereq.Kubeconfig.ServiceAccount
      ])
  """
  @spec load(pipeline :: module() | {module(), keyword()}) :: t()
  def load(pipeline) do
    pipeline =
      pipeline
      |> List.wrap()
      |> Enum.map(&ensure_step_opts_tuple/1)

    Pluggable.run(%__MODULE__{}, pipeline)
  end

  defp ensure_step_opts_tuple(module) when is_atom(module), do: {module, []}
  defp ensure_step_opts_tuple({module, opts}), do: {module, opts}

  defp access_by_name!(name), do: Access.find!(&(&1["name"] == name))
end
