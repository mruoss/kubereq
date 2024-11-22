defmodule Kubereq.Step do
  @moduledoc false

  alias Kubereq.Error.StepError
  alias Kubereq.Step

  @spec attach(Req.Request.t()) :: Req.Request.t()
  def attach(req) do
    req
    |> Req.Request.prepend_request_steps(kubereq: &call/1)
    |> Req.Request.register_options([
      :resource_path,
      :api_version,
      :field_selectors,
      :kind,
      :context,
      :kubeconfig,
      :label_selectors,
      :operation,
      :subresource
    ])
  end

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(req)
      when not is_map_key(req.options, :resource_path) and not is_map_key(req.options, :kind) do
    req
  end

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(req) when not is_map_key(req.options, :kubeconfig) do
    {req, StepError.new(:kubeconfig_not_loaded)}
  end

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(req) when not is_map_key(req.options, :kubeconfig) do
    {req, StepError.new(:kubeconfig_not_loaded)}
  end

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(req)
      when not is_map_key(req.options, :operation) do
    {req, StepError.new(:operation_missing)}
  end

  def call(req) do
    with %Req.Request{} = req <- Step.Context.call(req),
         %Req.Request{} = req <- Step.Plug.call(req),
         %Req.Request{} = req <- Step.BaseURL.call(req),
         %Req.Request{} = req <- Step.Operation.call(req),
         %Req.Request{} = req <- Step.Impersonate.call(req),
         %Req.Request{} = req <- Step.Auth.call(req),
         %Req.Request{} = req <- Step.TLS.call(req),
         %Req.Request{} = req <- Step.Compression.call(req),
         %Req.Request{} = req <- Step.FieldSelector.call(req) do
      Step.LabelSelector.call(req)
    end
  end
end
