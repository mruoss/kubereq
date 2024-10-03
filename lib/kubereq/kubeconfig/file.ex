defmodule Kubereq.Kubeconfig.File do
  @moduledoc """
  Pluggable step that load the Kubeconfig from a file.

  ```
  step Kubereq.Kubeconfig.File, path: "path/to/kubeconfig-integration.yaml"
  ```

  If the config file defined by the `:path` option is not found on disk, by
  default, the step gracefully returns the kubeconfig that was passed as
  argument. If you want the step to raise an `ArgumentException` instead, you
  can set the option `!: true`.

  ### Options

  * `:path` - Path to the config file.
  * `:!` - (optional. And yes, that's a valid atom) Raise an exception if the
    config file is not found. Defaults to `false`.
  * `:context` - (optional) Sets the current context in case there's multiple
    contexts defined in the config file. Defaults to what's defined in the
    "current-context" field in the loaded config.
  """

  alias Kubeconf

  @behaviour Pluggable

  @impl true
  @spec init(keyword()) :: keyword()
  def init(opts) do
    if !opts[:path] do
      raise ArgumentError, "Please pass a :path option contatining the path to the config file."
    end

    Keyword.validate!(opts, [:path, :context, :!])
  end

  @impl true
  @spec call(Kubereq.Kubeconfig.t(), any()) :: Kubereq.Kubeconfig.t()
  def call(kubeconf, opts) do
    if !opts[:path] do
      raise ArgumentError, "Please pass a :path option contatining the path to the config file."
    end

    path = Path.expand(opts[:path])
    raise? = Keyword.get(opts, :!, false)

    case File.exists?(path) do
      false when raise? ->
        raise ArgumentError, "No Kubernetes config file found at #{path}."

      false ->
        kubeconf

      true ->
        config = YamlElixir.read_from_file!(path)

        Kubereq.Kubeconfig.new!(
          clusters: config["clusters"],
          users: config["users"],
          contexts: config["contexts"]
        )
        |> Kubereq.Kubeconfig.set_current_context(opts[:context] || config["current-context"])
        |> Pluggable.Token.halt()
    end
  end
end
