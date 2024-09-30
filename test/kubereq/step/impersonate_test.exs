defmodule Kubereq.Step.ImpersonateTest do
  use ExUnit.Case, async: true

  alias Kubereq.Step.Impersonate, as: MUT

  test "raises if no kubeconfig" do
    {_req, error} = MUT.call(Req.new())
    assert is_struct(error, Kubereq.Error.StepError)
    assert error.code == :kubeconfig_not_loaded
  end

  @tag :wip
  test "Sets impersonation headers" do
    kubeconfig =
      Kubereq.Kubeconfig.new!(
        current_cluster: %{"server" => "https://example.com"},
        current_user: %{
          "as" => "calvin",
          "as-uid" => "123",
          "as-groups" => ["foo-grp", "bar-grp"],
          "as-user-extra" => %{
            "dn" => ["cn=calvin,ou=engineers,dc=example,dc=com"],
            "scopes" => ["view", "development"]
          }
        }
      )

    Kubereq.new(kubeconfig: kubeconfig)
    |> MUT.call()
    |> Req.merge(
      plug: fn conn ->
        assert {"impersonate-user", "calvin"} in conn.req_headers
        assert {"impersonate-uid", "123"} in conn.req_headers
        assert {"impersonate-group", "foo-grp"} in conn.req_headers
        assert {"impersonate-group", "bar-grp"} in conn.req_headers

        assert {"impersonate-extra-dn", "cn=calvin,ou=engineers,dc=example,dc=com"} in conn.req_headers
        assert {"impersonate-extra-scopes", "view"} in conn.req_headers
        assert {"impersonate-extra-scopes", "development"} in conn.req_headers

        Req.Test.json(conn, %{})
      end
    )
    |> Req.request()
  end
end
