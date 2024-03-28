defmodule Kubereq.Step.BaseUrlTest do
  use ExUnit.Case, async: true

  alias Kubereq.Step.BaseUrl, as: MUT

  test "raises if no kubeconfig" do
    assert_raise Kubereq.Error.StepError, fn -> MUT.call(Req.new()) end
  end

  test "sets the base url" do
    kubeconfig = Kubereq.Kubeconfig.new!(current_cluster: %{"server" => "https://example.com"})

    kubeconfig
    |> Kubereq.new("unused")
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
