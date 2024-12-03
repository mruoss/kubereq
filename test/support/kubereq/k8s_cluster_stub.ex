defmodule Kubereq.K8sClusterStub do
  @moduledoc false

  use Plug.Router

  require Logger

  plug(:match)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    json_decoder: Jason
  )

  plug(:dispatch)

  get "/api/v1/configmaps" do
    cond do
      conn.params["watch"] && conn.params["resourceVersion"] == "1" ->
        Req.Test.text(
          conn,
          """
          {"object":{"metadata":{"resourceVersion":2}},"type":"ADDED"}
          {"object":{"metadata":{"resourceVersion":3}},"type":"MODIFIED"}
          {"object":{"metadata":{"resourceVersion":4}},"type":"DELETED"}
          """
        )

      conn.params["watch"] ->
        Req.Test.text(conn, "")

      true ->
        Req.Test.json(conn, %{"metadata" => %{"resourceVersion" => "1"}, "items" => []})
    end
  end

  match _ do
    Logger.error("Unimplemented #{conn.method} Stub Request to #{conn.request_path}")

    conn
    |> put_status(500)
    |> Req.Test.text("Endpoint not implemented")
  end
end
