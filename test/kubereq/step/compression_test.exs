defmodule Kubereq.Step.CompressionTest do
  use ExUnit.Case, async: true

  alias Kubereq.Step.Compression, as: MUT

  test "raises if no kubeconfig" do
    {_req, error} = MUT.call(Req.new())
    assert is_struct(error, Kubereq.Error.StepError)
    assert error.code == :kubeconfig_not_loaded
  end

  test "enables compression by default" do
    kubeconfig =
      Kubereq.Kubeconfig.new!(current_cluster: %{"server" => "https://example.com"})

    req =
      kubeconfig
      |> Kubereq.new("unused")
      |> MUT.call()
      |> Req.merge(
        plug: fn conn ->
          assert {"content-encoding", "gzip"} in conn.req_headers
          Req.Test.json(conn, %{})
        end
      )

    Req.request(req, body: %{})
  end

  test "enables compression upon request" do
    kubeconfig =
      Kubereq.Kubeconfig.new!(
        current_cluster: %{"server" => "https://example.com", "disable-compression" => false}
      )

    kubeconfig
    |> Kubereq.new("unused")
    |> MUT.call()
    |> Req.merge(
      plug: fn conn ->
        assert {"content-encoding", "gzip"} in conn.req_headers
        Req.Test.json(conn, %{})
      end
    )
    |> Req.request(body: %{})
  end

  test "disables compression upon request" do
    kubeconfig =
      Kubereq.Kubeconfig.new!(
        current_cluster: %{"server" => "https://example.com", "disable-compression" => true}
      )

    kubeconfig
    |> Kubereq.new("unused")
    |> MUT.call()
    |> Req.merge(
      plug: fn conn ->
        refute {"content-encoding", "gzip"} in conn.req_headers
        Req.Test.json(conn, %{})
      end
    )
    |> Req.request(body: %{})
  end

  test "disables compression if request body is nil" do
    kubeconfig =
      Kubereq.Kubeconfig.new!(current_cluster: %{"server" => "https://example.com"})

    kubeconfig
    |> Kubereq.new("unused")
    |> MUT.call()
    |> Req.merge(
      plug: fn conn ->
        refute {"content-encoding", "gzip"} in conn.req_headers
        Req.Test.json(conn, %{})
      end
    )
    |> Req.request()
  end
end
