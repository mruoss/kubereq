defmodule Kubereq.Step.BaseURL do
  @moduledoc false

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(req) do
    Req.merge(req, base_url: req.options.kubeconfig.current_cluster["server"])
  end
end
