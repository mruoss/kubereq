defmodule Kubereq.Step.Plug do
  @moduledoc """
  Req step to derive the base URL to the cluster.
  """

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(req) do
    case req.options.kubeconfig.current_cluster["plug"] do
      nil -> req
      plug -> Req.merge(req, plug: plug)
    end
  end
end
