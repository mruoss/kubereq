defmodule Kubereq.Step.BaseUrl do
  @moduledoc """
  Pluggable step to derive the base URL to the cluster.
  """

  alias Kubereq.Error.StepError

  @spec attach(Req.Request.t()) :: Req.Request.t()
  def attach(req) do
    Req.Request.prepend_request_steps(req, kubereq_base_url: &call/1)
  end

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(%Req.Request{options: %{kubeconfig: nil}}) do
    raise StepError.new(:kubeconfig_not_loaded)
  end

  def call(req) do
    Req.merge(req, base_url: req.options.kubeconfig.current_cluster["server"])
  end
end
