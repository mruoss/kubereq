defmodule Kubereq.Step.PlugTest do
  use ExUnit.Case, async: true

  alias Kubereq.Step.Plug, as: MUT

  alias Kubereq.Kubeconfig

  test "raises if no kubeconfig" do
    {_req, error} = MUT.call(Req.new())
    assert is_struct(error, Kubereq.Error.StepError)
    assert error.code == :kubeconfig_not_loaded
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
      Kubereq.new(kubeconfig: kubeconfig)
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
      Kubeconfig.Stub.call(%Kubeconfig{}, Kubeconfig.Stub.init(plugs: plugs))
      |> Kubeconfig.set_current_context("foo")

    {:ok, resp} =
      Kubereq.new(kubeconfig: kubeconfig)
      |> MUT.call()
      |> Req.request()

    assert resp.body == "Foo called"

    {:ok, resp} =
      Kubereq.new(kubeconfig: Kubeconfig.set_current_context(kubeconfig, "bar"))
      |> MUT.call()
      |> Req.request()

    assert resp.body == "Bar called"
  end
end
