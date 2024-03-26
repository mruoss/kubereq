defmodule Kubereq.Step.CompressionTest do
  use ExUnit.Case

  alias Kubereq.Step.Compression, as: MUT

  test "raises if no kubeconfig" do
    assert_raise Kubereq.Error.StepError, fn -> MUT.call(Req.new()) end
  end

  test "enables compression by default" do
    kubeconfig =
      Kubeconf.new!(current_cluster: %{"server" => "https://example.com"})

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
      Kubeconf.new!(
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
      Kubeconf.new!(
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
      Kubeconf.new!(current_cluster: %{"server" => "https://example.com"})

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
