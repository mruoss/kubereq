defmodule Kubereq.Step.BaseUrlTest do
  use ExUnit.Case, async: true

  alias Kubereq.Step.BaseUrl, as: MUT

  test "raises if no kubeconfig" do
    {_req, error} = MUT.call(Req.new())
    assert is_struct(error, Kubereq.Error.StepError)
    assert error.code == :kubeconfig_not_loaded
  end

  test "sets the base url" do
    kubeconfig = Kubereq.Kubeconfig.new!(current_cluster: %{"server" => "https://example.com"})

    Kubereq.new(kubeconfig: kubeconfig)
    |> MUT.call()
    |> Req.merge(
      plug: fn conn ->
        assert "example.com" === conn.host
        Req.Test.json(conn, %{})
      end
    )
    |> Req.request()
  end
end
