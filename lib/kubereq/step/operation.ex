defmodule Kubereq.Step.Operation do
  @moduledoc """
  Req step to derive the options for the given operation.
  """

  alias Kubereq.Error.StepError

  @spec attach(Req.Request.t()) :: Req.Request.t()
  def attach(req) do
    req
    |> Req.Request.prepend_request_steps(kubereq_operation: &call/1)
    |> Req.Request.register_options([
      :operation,
      :api_version,
      :kind,
      :subresource
    ])
  end

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(req) when not is_map_key(req.options, :kubeconfig) do
    {req, StepError.new(:kubeconfig_not_loaded)}
  end

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(req)
      when not is_map_key(req.options, :api_version) or not is_map_key(req.options, :kind) do
    {req, StepError.new(:gvk_missing)}
  end

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(req)
      when not is_map_key(req.options, :operation) do
    {req, StepError.new(:operation_missing)}
  end

  def call(req) do
    case Kubereq.Discovery.resource_path_for(req, req.options.api_version, req.options.kind) do
      {:ok, resource_path} ->
        request_path =
          if req.options.path_params[:namespace],
            do: resource_path,
            else: String.replace(resource_path, "/namespace/:namespace", "")

        options =
          operation(req.options.operation, request_path, req.options[:subresource])
          |> Keyword.put(:base_url, req.options.kubeconfig.current_cluster["server"])

        Req.merge(req, options)

      :error ->
        {req,
         %StepError{
           code: :resource_not_found,
           message:
             ~s|The requested resource "#{req.options.kind}" of apiVersion "#{req.options.api_version} does not exist on the cluster."|
         }}
    end
  end

  defp operation(:get, request_path, subresource) do
    [url: "#{request_path}/#{subresource}", method: :get]
  end

  defp operation(:create, request_path, subresource) do
    case subresource do
      nil ->
        [url: String.replace_suffix(request_path, "/:name", ""), method: :post]

      subresource ->
        [url: "#{request_path}/#{subresource}", method: :post]
    end
  end

  defp operation(:update, request_path, subresource) do
    [url: "#{request_path}/#{subresource}", method: :put]
  end

  defp operation(:list, request_path, _subresource) do
    [url: String.replace_suffix(request_path, "/:name", ""), method: :get]
  end

  defp operation(:watch, request_path, _subresource) do
    [
      url: String.replace_suffix(request_path, "/:name", ""),
      method: :get,
      params: [watch: "1", allowWatchBookmarks: "1"],
      receive_timeout: :infinity,
      into: :self
    ]
  end

  defp operation(:delete, request_path, _subresource) do
    [url: String.replace_suffix(request_path, "/:name", ""), method: :delete]
  end

  defp operation(:delete_all, request_path, _subresource) do
    [url: "#{request_path}", method: :delete]
  end

  defp operation(:apply, request_path, subresource) do
    [
      url: "#{request_path}/#{subresource}",
      method: :patch,
      headers: [{"Content-Type", "application/apply-patch+yaml"}]
    ]
  end

  defp operation(:json_patch, request_path, subresource) do
    [
      url: "#{request_path}/#{subresource}",
      method: :patch,
      headers: [{"Content-Type", "application/json-patch+json"}]
    ]
  end

  defp operation(:merge_patch, request_path, subresource) do
    [
      url: "#{request_path}/#{subresource}",
      method: :patch,
      headers: [{"Content-Type", "application/merge-patch+json"}]
    ]
  end
end
