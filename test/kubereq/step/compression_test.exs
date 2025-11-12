defmodule Kubereq.Step.CompressionTest do
  use ExUnit.Case, async: true

  setup do
    Req.Test.verify_on_exit!()
  end

  test "enables compression by default" do
    req =
      Req.new()
      |> Kubereq.attach(
        kubeconfig: {Kubereq.Kubeconfig.Stub, plugs: {Req.Test, Kubereq.Stub}},
        operation: :create,
        body: %{},
        api_version: "v1",
        kind: "ConfigMap"
      )
      |> Req.Request.prepare()

    assert Req.Request.get_header(req, "content-encoding") == ["gzip"]
  end

  test "enables compression upon request" do
    kubeconfig =
      Kubereq.Kubeconfig.load({Kubereq.Kubeconfig.Stub, plugs: {Req.Test, Kubereq.Stub}})

    kubeconfig = update_in(kubeconfig.current_cluster, &Map.put(&1, "disable-compression", false))

    req =
      Req.new()
      |> Kubereq.attach(
        kubeconfig: kubeconfig,
        operation: :create,
        body: %{},
        api_version: "v1",
        kind: "ConfigMap"
      )
      |> Req.Request.prepare()

    assert Req.Request.get_header(req, "content-encoding") == ["gzip"]
  end

  test "disables compression upon request" do
    kubeconfig =
      Kubereq.Kubeconfig.load({Kubereq.Kubeconfig.Stub, plugs: {Req.Test, Kubereq.Stub}})

    kubeconfig = update_in(kubeconfig.current_cluster, &Map.put(&1, "disable-compression", true))

    req =
      Req.new()
      |> Kubereq.attach(
        kubeconfig: kubeconfig,
        operation: :create,
        body: %{},
        api_version: "v1",
        kind: "ConfigMap"
      )
      |> Req.Request.prepare()

    assert Req.Request.get_header(req, "content-encoding") == []
  end

  test "disables compression if request body is nil" do
    kubeconfig =
      Kubereq.Kubeconfig.load({Kubereq.Kubeconfig.Stub, plugs: {Req.Test, Kubereq.Stub}})

    kubeconfig = update_in(kubeconfig.current_cluster, &Map.put(&1, "disable-compression", true))

    req =
      Req.new()
      |> Kubereq.attach(
        kubeconfig: kubeconfig,
        operation: :create,
        body: %{},
        api_version: "v1",
        kind: "ConfigMap"
      )
      |> Req.Request.prepare()

    assert Req.Request.get_header(req, "content-encoding") == []
  end
end
