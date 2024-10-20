defmodule Kubereq.Step.Context do
  @moduledoc false

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(req) do
    case req.options[:context] do
      nil ->
        req

      context ->
        update_in(req.options.kubeconfig, &Kubereq.Kubeconfig.set_current_context(&1, context))
    end
  end
end
