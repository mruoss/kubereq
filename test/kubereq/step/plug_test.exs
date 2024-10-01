defmodule Kubereq.Step.PlugTest do
  use ExUnit.Case, async: true

  alias Kubereq.Step.Plug, as: MUT

  alias Kubereq.Kubeconfig

  test "sets a single plug on the req" do
    Req.Test.stub(Kubereq.Step.PlugTest, fn conn ->
      assert conn.host == "default"
      Plug.Conn.send_resp(conn, 200, "Plug called")
    end)

    kubeconfig =
      Kubeconfig.Stub.call(
        %Kubeconfig{},
        Kubeconfig.Stub.init(plugs: {Req.Test, Kubereq.Step.PlugTest})
      )

    {:ok, resp} =
      Req.new()
      |> Kubereq.attach(kubeconfig: kubeconfig)
      |> MUT.call()
      |> Req.request(
        api_version: "v1",
        kind: "ConfigMap",
        operation: :get,
        path_params: [name: "foo"]
      )

    assert resp.body == "Plug called"
  end

  test "sets multiple plugs on the req" do
    Req.Test.stub(Kubereq.Step.Foo, fn conn ->
      assert conn.host == "foo"
      Plug.Conn.send_resp(conn, 200, "Foo called")
    end)

    Req.Test.stub(Kubereq.Step.Bar, fn conn ->
      assert conn.host == "bar"
      Plug.Conn.send_resp(conn, 200, "Bar called")
    end)

    plugs = %{
      "foo" => {Req.Test, Kubereq.Step.Foo},
      "bar" => {Req.Test, Kubereq.Step.Bar}
    }

    kubeconfig =
      Kubeconfig.Stub.call(%Kubeconfig{}, Kubeconfig.Stub.init(plugs: plugs))
      |> Kubeconfig.set_current_context("foo")

    {:ok, resp} =
      Req.new()
      |> Kubereq.attach(kubeconfig: kubeconfig)
      |> MUT.call()
      |> Req.request(
        api_version: "v1",
        kind: "ConfigMap",
        operation: :get,
        path_params: [name: "foo"]
      )

    assert resp.body == "Foo called"

    {:ok, resp} =
      Req.new()
      |> Kubereq.attach(kubeconfig: Kubeconfig.set_current_context(kubeconfig, "bar"))
      |> MUT.call()
      |> Req.request(
        api_version: "v1",
        kind: "ConfigMap",
        operation: :get,
        path_params: [name: "foo"]
      )

    assert resp.body == "Bar called"
  end
end
