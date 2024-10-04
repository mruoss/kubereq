defmodule Kubereq.StepTest do
  use ExUnit.Case, async: true

  alias Kubereq.Step, as: MUT

  test "raises if no kubeconfig" do
    {_req, error} =
      Req.new()
      |> Req.Request.register_options([:resource_path])
      |> Req.merge(resource_path: "https://foo")
      |> MUT.call()

    assert is_struct(error, Kubereq.Error.StepError)
    assert error.code == :kubeconfig_not_loaded
  end
end
