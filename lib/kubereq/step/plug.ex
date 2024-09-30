defmodule Kubereq.Step.Plug do
  @moduledoc """
  Req step to derive the base URL to the cluster.
  """

  alias Kubereq.Error.StepError

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(req) when not is_map_key(req.options, :kubeconfig) do
    {req, StepError.new(:kubeconfig_not_loaded)}
  end

  def call(req) do
    case req.options.kubeconfig.current_cluster["plug"] do
      nil -> req
      plug -> Req.merge(req, plug: plug)
    end
  end
end
