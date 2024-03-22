defmodule Kubereq.Error.StepError do
  @enforce_keys [:message, :code]
  defexception [:message, :code, upstream: nil]

  @type t :: %__MODULE__{message: String.t(), code: atom(), upstream: Exception.t()}

  @errors %{
    kubeconfig_not_loaded:
      "The KubeConfig is not loaded. Make sure to add a Kubereq.Kubeconfig.* step before this one."
  }

  @spec new(atom(), Exception.t() | nil) :: t()
  def new(code, upstream \\ nil)

  for {code, message} <- @errors do
    def new(unquote(code), upstream) do
      struct!(__MODULE__, code: unquote(code), message: unquote(message), upstream: upstream)
    end
  end
end
