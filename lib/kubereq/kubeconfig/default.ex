defmodule Kubereq.Kubeconfig.Default do
  @moduledoc """
  Default pipeline of pluggable steps for loading the Kubeconfig. Tries to
  build the Kubeconfig from different default settings.

  1. Checks for the `KUBECONFIG` environment variable. If it is set and pointing
     to a Kubeconfig file, that file is imported.
  1. Checks for `$HOME/.kube/config`.
  1. Checks if running inside a Cluster and tries to connect using the Service
     Account Token.

  ### Example

  Usage in a pipeline created with `Pluggable.StepBuilder`:

      defmodule MyApp.KubeconfLoader do
        use Pluggable.StepBuilder

        step Kubereq.Kubeconfig.Default
      end
  """

  use Pluggable.StepBuilder

  step(Kubereq.Kubeconfig.ENV)
  step(Kubereq.Kubeconfig.File, path: ".kube/config", relative_to_home?: true)
  step(Kubereq.Kubeconfig.ServiceAccount)
end
