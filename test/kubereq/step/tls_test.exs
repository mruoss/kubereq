defmodule Kubereq.Step.TLSTest do
  use ExUnit.Case, async: true

  alias Kubereq.Step.TLS, as: MUT

  test "raises if no kubeconfig" do
    {_req, error} = MUT.call(Req.new())
    assert is_struct(error, Kubereq.Error.StepError)
    assert error.code == :kubeconfig_not_loaded
  end

  test "sets the verify option" do
    kubeconfig = Kubereq.Kubeconfig.new!(current_cluster: %{"server" => "https://example.com"})
    req = Kubereq.new(kubeconfig: kubeconfig) |> MUT.call()
    assert :verify_peer === get_in(req.options, ~w"connect_options transport_opts verify"a)

    kubeconfig =
      Kubereq.Kubeconfig.new!(
        current_cluster: %{"server" => "https://example.com", "insecure-skip-tls-verify" => true}
      )

    req = Kubereq.new(kubeconfig: kubeconfig) |> MUT.call()
    assert :verify_none === get_in(req.options, ~w"connect_options transport_opts verify"a)
  end

  test "sets the cacertfile option" do
    kubeconfig =
      Kubereq.Kubeconfig.new!(
        current_cluster: %{
          "server" => "https://example.com",
          "certificate-authority" => "/path/to/ca.crt"
        }
      )

    req = Kubereq.new(kubeconfig: kubeconfig) |> MUT.call()

    assert ~c"/path/to/ca.crt" ===
             get_in(req.options, ~w"connect_options transport_opts cacertfile"a)
  end

  test "sets the cacert option" do
    kubeconfig =
      Kubereq.Kubeconfig.new!(
        current_cluster: %{
          "server" => "https://example.com",
          "certificate-authority-data" =>
            "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUM5RENDQWR5Z0F3SUJBZ0lJY0FwYS9xZlNVc013RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB4T0RFeE1Ua3dNREk1TlRGYUZ3MHhPVEV5TVRFd01qQTNORGhhTURZeApGekFWQmdOVkJBb1REbk41YzNSbGJUcHRZWE4wWlhKek1Sc3dHUVlEVlFRREV4SmtiMk5yWlhJdFptOXlMV1JsCmMydDBiM0F3Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLQW9JQkFRRFJqRzdZK2xSN1VlbnMKVUo1aGkvRWlnem53bnpQdWR4NkJLZjkwaG9zVldpeFlZVmlZQ2FYWXhiUk1RMDZQUUhXV2ZVWGEvcEZqWTdQUwpjMllyZ05JZU1oMm5XS2hKbUFGelc5ZFRsV0QrUkNmS3dRVlFYa3ZBVS8rUVczU3pvRUpieHRpczRIc0Vyc2tvCllkeVcxb2hRSm1yc3MxakYzZE93NTQ5cElUSUM3T3VZd0ZQVmx3TWprUmNKUUpMbjJ4UjBIVCt1UmUxTHp0UEoKK2QwdTkvYmpSTERpbnVJYWZhYjZzN3M3Nk52YmJVYXBsSy82RnVxbzhhNUt4Z0lOYXJPNkVHWlZuRU1XMVVxNAorNFVVb1lrdVRWcXJVTlBvSzJ5Yy9wamxySENna3dpTTU3cXNQS00yWVNXRTlXSFZGMGZyZS81bzZtRGRUOU1TCkg5d3ZqNm8vQWdNQkFBR2pKekFsTUE0R0ExVWREd0VCL3dRRUF3SUZvREFUQmdOVkhTVUVEREFLQmdnckJnRUYKQlFjREFqQU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FRRUFhOHJKUHVsQlMxYWRnb1J5WGo4ak9ZaVpjV3crNUJZTwpuQW5JS2hBWVEvZHBMYXhhcG4zODNHVS9ZeGhKM3E3azExNnZBSmdRTkdPNXBHS3M2b3k3M2FWMGd6ZU00ZklGCnlFN0dNTG1BQVN6QzRJUlIvc0JOWUlKbTlaZERsbmVicEJxTkhIUWt5dlJpdWNMdjFDVDl4dTI0NTBoOW5RSlAKWTJQSmVMSVRhYUhNWVk5eTBPWnQvOGVoNnFyTks2RlY5VWN4bnZYVHQwUW1qL0k2aXdlZ1BVb0t2Vm5aamF0ZQpLOHJMdlQ3SXJLSDRubGRrOUNtclYyZTMwT3IzRVFHeXlOM0xJTGlBa3R2Z3BHNXlLd2s1M2RPSzJtNkl4QTlyCnBzMFRYUmUxMUhlVVhsWm1PcERKVHMwa3VzTGVjVE05ZW5MN1VhK3RSakRtR08xTFo0RDFidz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K"
        }
      )

    req = Kubereq.new(kubeconfig: kubeconfig) |> MUT.call()

    cacerts = get_in(req.options, ~w"connect_options transport_opts cacerts"a)
    assert is_list(cacerts)
    assert length(cacerts) == 1
  end

  test "sets the SNI option" do
    kubeconfig =
      Kubereq.Kubeconfig.new!(
        current_cluster: %{
          "server" => "https://example.com",
          "tls-server-name" => "localhost"
        }
      )

    req = Kubereq.new(kubeconfig: kubeconfig) |> MUT.call()

    assert ~c"localhost" ===
             get_in(req.options, ~w"connect_options transport_opts server_name_indication"a)
  end
end
