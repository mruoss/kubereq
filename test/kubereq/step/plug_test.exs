defmodule Kubereq.Step.PlugTest do
  use ExUnit.Case, async: true

  alias Kubereq.Step.Plug, as: MUT

  alias Kubereq.Kubeconfig

  test "raises if no kubeconfig" do
    assert_raise Kubereq.Error.StepError, fn -> MUT.call(Req.new()) end
  end

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
      kubeconfig
      |> Kubereq.new("unused")
      |> MUT.call()
      |> Req.request()

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
      Kubeconfig.Stub.call(
        %Kubeconfig{},
        Kubeconfig.Stub.init(plugs: plugs)
      )

    {:ok, resp} =
      kubeconfig
      |> Kubeconfig.set_current_context("foo")
      |> Kubereq.new("unused")
      |> MUT.call()
      |> Req.request()

    assert resp.body == "Foo called"

    {:ok, resp} =
      kubeconfig
      |> Kubeconfig.set_current_context("bar")
      |> Kubereq.new("unused")
      |> MUT.call()
      |> Req.request()

    assert resp.body == "Bar called"
  end
end
