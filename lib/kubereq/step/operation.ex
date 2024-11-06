defmodule Kubereq.Step.Operation do
  @moduledoc false

  alias Kubereq.Error.StepError

  @spec call(req :: Req.Request.t()) :: Req.Request.t() | {Req.Request.t(), StepError.t()}
  def call(req) when not is_map_key(req.options, :operation) or is_nil(req.options.operation) do
    req
  end

  def call(req) do
    case resource_path(req) do
      {:ok, resource_path} ->
        request_path =
          if req.options[:path_params][:namespace],
            do: resource_path,
            else: String.replace(resource_path, "/namespaces/:namespace", "")

        options = operation(req.options.operation, request_path, req.options[:subresource])

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

  defp resource_path(%{options: %{resource_path: resource_path}}), do: {:ok, resource_path}

  defp resource_path(req) do
    Kubereq.Discovery.resource_path_for(req, req.options[:api_version], req.options.kind)
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
    [url: request_path, method: :delete]
  end

  defp operation(:delete_all, request_path, _subresource) do
    [url: String.replace_suffix(request_path, "/:name", ""), method: :delete]
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

  defp operation(:connect, request_path, subresource) do
    [
      url: "#{request_path}/#{subresource}"
    ]
  end
end
