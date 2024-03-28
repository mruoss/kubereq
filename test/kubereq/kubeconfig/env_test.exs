defmodule Kubereq.Kubeconfig.ENVTest do
  use ExUnit.Case

  alias Kubereq.Kubeconfig.ENV, as: MUT

  test "imports config from file at location of KUBECONFIG env var" do
    System.put_env("KUBECONFIG", "test/support/kubeconfig-unit.yaml")
    kubeconfig = MUT.call(%Kubereq.Kubeconfig{}, [])
    assert 4 === length(kubeconfig.clusters)
    assert 7 === length(kubeconfig.users)
    assert 3 === length(kubeconfig.contexts)
    assert "https://localhost:6443" === kubeconfig.current_cluster["server"]
    assert Map.has_key?(kubeconfig.current_user, "client-certificate-data")
  end

  test "imports config from file at location of custom env var" do
    env_var_name = "FOOCONFIG"
    System.put_env(env_var_name, "test/support/kubeconfig-unit.yaml")
    kubeconfig = MUT.call(%Kubereq.Kubeconfig{}, MUT.init(env_var: env_var_name))
    assert 4 === length(kubeconfig.clusters)
    assert 7 === length(kubeconfig.users)
    assert 3 === length(kubeconfig.contexts)
    assert "https://localhost:6443" === kubeconfig.current_cluster["server"]
    assert Map.has_key?(kubeconfig.current_user, "client-certificate-data")
  end

  test "raises if file not found but only if !: true" do
    System.put_env("KUBECONFIG", "/does/not/exist")

    assert_raise(
      ArgumentError,
      "No Kubernetes config file found at /does/not/exist.",
      fn -> MUT.call(%Kubereq.Kubeconfig{}, MUT.init(!: true)) end
    )

    _kubeconfig = MUT.call(%Kubereq.Kubeconfig{}, MUT.init([]))
  end

  test "init/1 raises if unsupported options passed" do
    assert_raise ArgumentError, fn -> MUT.init(foo: :bar) end
  end
end
