defmodule Kubereq.Discovery do
  @moduledoc false

  def resource_path_for(_req, nil, kind) do
    case Kubereq.Discovery.ResourcePathMapping.lookup(kind) do
      nil -> :error
      path -> {:ok, path}
    end
  end

  def resource_path_for(req, group_version, kind) do
    with {:ok, nil} <-
           {:ok, Kubereq.Discovery.ResourcePathMapping.lookup("#{group_version}/#{kind}")},
         {:ok, resource} <- discover_resource_on_cluster(req, group_version, kind) do
      path =
        if resource["namespaced"] do
          "/apis/#{group_version}/namespaces/:namespace/#{resource["name"]}/:name"
        else
          "/apis/#{group_version}/#{resource["name"]}/:name"
        end

      {:ok, path}
    end
  end

  defp discover_resource_on_cluster(req, group_version, kind) do
    # fixme: endless loop!
    case Req.get(req, url: "/apis/#{group_version}", operation: nil) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case Enum.find(body["resources"], &(&1["kind"] == kind)) do
          nil -> :error
          resource -> {:ok, resource}
        end

      _ ->
        :error
    end
  end
end
