defmodule Kubereq.Kubeconfig.ENV do
  @moduledoc """
  Pluggable step that loads the Kubeconfig from a config file whose location is
  defined by an ENV variable. Uses `Kubereq.Kubeconfig.File` under the hood.

  ### Examples

      step Kubereq.Kubeconfig.ENV

  By default, this step assumes the name of the variable to be `KUBECONFIG`.
  This can be customized through the `:env_var` option

      step Kubereq.Kubeconfig.ENV, env_var: SPECIAL_KUBECONFIG

  ### Options

  * `env_var` - (optional) The name of the environment variable. Defaults to
    `KUBECONFIG`
  * `!` - (optional. And yes, that's a valid atom)
  """

  alias Kubereq.Kubeconfig.File

  @behaviour Pluggable

  @impl true
  @spec init(keyword()) :: keyword()
  def init(opts \\ []) do
    Keyword.validate!(opts, [:env_var, :!])
  end

  @impl true
  @spec call(Kubereq.Kubeconfig.t(), keyword()) :: Kubereq.Kubeconfig.t()
  def call(kubeconfig, opts) do
    env_var = opts[:env_var] || "KUBECONFIG"

    case System.get_env(env_var) do
      nil ->
        kubeconfig

      file_path ->
        file_opts = File.init(path: file_path, !: opts[:!])
        File.call(kubeconfig, file_opts)
    end
  end
end
