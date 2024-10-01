defmodule Kubereq.Step.CompressionTest do
  use ExUnit.Case, async: true

  setup do
    Req.Test.verify_on_exit!()
  end

  test "enables compression by default" do
    Req.Test.expect(Kubereq.Stub, fn conn ->
      assert {"content-encoding", "gzip"} in conn.req_headers
      Req.Test.json(conn, %{})
    end)

    {:ok, _} =
      Req.new()
      |> Kubereq.attach(kubeconfig: {Kubereq.Kubeconfig.Stub, plugs: {Req.Test, Kubereq.Stub}})
      |> Req.request(operation: :create, body: %{}, api_version: "v1", kind: "ConfigMap")
  end

  test "enables compression upon request" do
    Req.Test.expect(Kubereq.Stub, fn conn ->
      assert {"content-encoding", "gzip"} in conn.req_headers
      Req.Test.json(conn, %{})
    end)

    kubeconfig =
      Kubereq.Kubeconfig.load({Kubereq.Kubeconfig.Stub, plugs: {Req.Test, Kubereq.Stub}})

    kubeconfig = update_in(kubeconfig.current_cluster, &Map.put(&1, "disable-compression", false))

    {:ok, _} =
      Req.new()
      |> Kubereq.attach(
        kubeconfig: kubeconfig,
        body: %{}
      )
      |> Req.request(operation: :create, body: %{}, api_version: "v1", kind: "ConfigMap")
  end

  test "disables compression upon request" do
    Req.Test.expect(Kubereq.Stub, fn conn ->
      refute {"content-encoding", "gzip"} in conn.req_headers
      Req.Test.json(conn, %{})
    end)

    kubeconfig =
      Kubereq.Kubeconfig.load({Kubereq.Kubeconfig.Stub, plugs: {Req.Test, Kubereq.Stub}})

    kubeconfig = update_in(kubeconfig.current_cluster, &Map.put(&1, "disable-compression", true))

    {:ok, _} =
      Req.new()
      |> Kubereq.attach(
        kubeconfig: kubeconfig,
        body: %{}
      )
      |> Req.request(operation: :create, body: %{}, api_version: "v1", kind: "ConfigMap")
  end

  test "disables compression if request body is nil" do
    Req.Test.expect(Kubereq.Stub, fn conn ->
      refute {"content-encoding", "gzip"} in conn.req_headers
      Req.Test.json(conn, %{})
    end)

    kubeconfig =
      Kubereq.Kubeconfig.load({Kubereq.Kubeconfig.Stub, plugs: {Req.Test, Kubereq.Stub}})

    kubeconfig = update_in(kubeconfig.current_cluster, &Map.put(&1, "disable-compression", true))

    {:ok, _} =
      Req.new()
      |> Kubereq.attach(
        kubeconfig: kubeconfig,
        body: %{}
      )
      |> Req.request(operation: :create, body: %{}, api_version: "v1", kind: "ConfigMap")
  end
end
