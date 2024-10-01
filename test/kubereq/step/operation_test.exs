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
end
