defmodule Kubereq.Step.OperationTest do
  use ExUnit.Case, async: true

  alias Kubereq.Step.Operation, as: MUT

  test "raises if no kubeconfig" do
    {_req, error} = MUT.call(Req.new())
    assert is_struct(error, Kubereq.Error.StepError)
    assert error.code == :kubeconfig_not_loaded
  end

  # TODO: implement more tests
end
