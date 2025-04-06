defmodule Kubereq.Step.BaseURL do
  @moduledoc false

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(req) do
    current_cluster = req.options.kubeconfig.current_cluster

    req
    |> Req.merge(base_url: current_cluster["server"])
    |> maybe_add_proxy_url(current_cluster["proxy-url"])
  end

  defp maybe_add_proxy_url(req, nil), do: req

  defp maybe_add_proxy_url(req, proxy_url) do
    uri = URI.parse(proxy_url)

    connect_options =
      req.options[:connect_options]
      |> List.wrap()
      |> Keyword.merge(proxy: {scheme_to_atom(uri.scheme), uri.host, uri.port, []})

    Req.merge(req, connect_options: connect_options)
  end

  defp scheme_to_atom("http"), do: :http
  defp scheme_to_atom("https"), do: :https
  defp scheme_to_atom("sock5"), do: :sock5
end
