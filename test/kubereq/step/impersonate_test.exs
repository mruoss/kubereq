defmodule Kubereq.Step.ImpersonateTest do
  use ExUnit.Case, async: true

  test "Sets impersonation headers" do
    plug = fn conn ->
      assert {"impersonate-user", "calvin"} in conn.req_headers
      assert {"impersonate-uid", "123"} in conn.req_headers
      assert {"impersonate-group", "foo-grp"} in conn.req_headers
      assert {"impersonate-group", "bar-grp"} in conn.req_headers

      assert {"impersonate-extra-dn", "cn=calvin,ou=engineers,dc=example,dc=com"} in conn.req_headers
      assert {"impersonate-extra-scopes", "view"} in conn.req_headers
      assert {"impersonate-extra-scopes", "development"} in conn.req_headers

      Req.Test.json(conn, %{})
    end

    kubeconfig =
      Kubereq.Kubeconfig.load({Kubereq.Kubeconfig.Stub, plugs: {Req.Test, plug}})
      |> struct!(
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

    Req.new()
    |> Kubereq.attach(kubeconfig: kubeconfig)
    |> Req.request(api_version: "v1", kind: "ConfigMap")
  end
end
