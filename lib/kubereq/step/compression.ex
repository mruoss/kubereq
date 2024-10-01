defmodule Kubereq.Step.Compression do
  @moduledoc """
  Req step to derive compression headers from the Kubeconfig.
  """

  alias Kubereq.Error.StepError

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(req) when not is_map_key(req.options, :kubeconfig) do
    {req, StepError.new(:kubeconfig_not_loaded)}
  end

  def call(req) do
    compression(req, req.options.kubeconfig.current_cluster)
  end

  @spec compression(Req.Request.t(), map()) :: Req.Request.t()
  defp compression(req, %{"disable-compression" => true}) do
    Req.merge(req, compress_body: false)
  end

  defp compression(req, _) do
    Req.merge(req, compress_body: not is_nil(req.body))
  end
end
