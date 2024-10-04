defmodule Kubereq.Step.OperationTest do
  use ExUnit.Case, async: true

  setup do
    Req.Test.verify_on_exit!()
  end

  test "doesn't set url if operation is missing" do
    kubeconfig = {Kubereq.Kubeconfig.Stub, plugs: {Req.Test, Kubereq.Stub}}

    {_req, error} =
      Req.new()
      |> Kubereq.attach(kubeconfig: kubeconfig)
      |> Req.request(api_version: "v1", kind: "ConfigMap")

    assert error.code == :operation_missing
  end

  test "Discovers core resources through static lookup" do
    kubeconfig = {Kubereq.Kubeconfig.Stub, plugs: {Req.Test, Kubereq.Stub}}

    Req.Test.stub(Kubereq.Stub, fn
      conn when conn.request_path === "/apis/v1" ->
        raise "Resource not found"

      conn ->
        Req.Test.json(conn, %{})
    end)

    {:ok, _} =
      Req.new()
      |> Kubereq.attach(kubeconfig: kubeconfig)
      |> Req.request(operation: :get, api_version: "v1", kind: "ConfigMap")
  end

  test "Discovers core resources through static lookup with unknown api_version" do
    kubeconfig = {Kubereq.Kubeconfig.Stub, plugs: {Req.Test, Kubereq.Stub}}

    Req.Test.stub(Kubereq.Stub, fn
      conn when conn.request_path === "/apis/v1" ->
        raise "Resource not found"

      conn ->
        Req.Test.json(conn, %{})
    end)

    {:ok, _} =
      Req.new()
      |> Kubereq.attach(kubeconfig: kubeconfig)
      |> Req.request(operation: :get, kind: "ConfigMap")
  end

  test "Discovers unknown resources through dynamic (cluster) lookup" do
    kubeconfig = {Kubereq.Kubeconfig.Stub, plugs: {Req.Test, Kubereq.Stub}}

    Req.Test.expect(Kubereq.Stub, fn conn ->
      Req.Test.json(conn, %{
        "resources" => [%{"kind" => "Foo", "name" => "foo", "namespaced" => true}]
      })
    end)

    Req.Test.expect(Kubereq.Stub, fn conn ->
      assert conn.request_path == "/apis/v1/namespaces/default/foo/bar/"
      Req.Test.json(conn, %{})
    end)

    {:ok, _} =
      Req.new()
      |> Kubereq.attach(kubeconfig: kubeconfig)
      |> Req.request(
        operation: :get,
        api_version: "v1",
        kind: "Foo",
        path_params: [name: "bar", namespace: "default"]
      )
  end

  test "cuts namespace from path if operation is list and no namespace is given" do
    kubeconfig = {Kubereq.Kubeconfig.Stub, plugs: {Req.Test, Kubereq.Stub}}

    Req.Test.expect(Kubereq.Stub, fn conn ->
      Req.Test.json(conn, %{
        "resources" => [%{"kind" => "Foo", "name" => "foo", "namespaced" => true}]
      })
    end)

    Req.Test.expect(Kubereq.Stub, fn conn ->
      assert conn.request_path == "/apis/v1/foo"
      Req.Test.json(conn, %{})
    end)

    {:ok, _} =
      Req.new()
      |> Kubereq.attach(kubeconfig: kubeconfig)
      |> Req.request(operation: :list, api_version: "v1", kind: "Foo")
  end
end
