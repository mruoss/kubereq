defmodule Kubereq.Kubeconfig.FileTest do
  use ExUnit.Case, async: true

  alias Kubereq.Kubeconfig.File, as: MUT

  test "Imports config from file" do
    kubeconfig =
      MUT.call(%Kubereq.Kubeconfig{}, MUT.init(path: "test/support/kubeconfig-unit.yaml"))

    assert 4 === length(kubeconfig.clusters)
    assert 7 === length(kubeconfig.users)
    assert 3 === length(kubeconfig.contexts)
    assert "https://localhost:6443" === kubeconfig.current_cluster["server"]
    assert Map.has_key?(kubeconfig.current_user, "client-certificate-data")
  end

  test "raises if file not found but only if !: true" do
    assert_raise(
      ArgumentError,
      "No Kubernetes config file found at /does/not/exist.",
      fn -> MUT.call(%Kubereq.Kubeconfig{}, MUT.init(path: "/does/not/exist", !: true)) end
    )

    _kubeconf = MUT.call(%Kubereq.Kubeconfig{}, MUT.init(path: "/does/not/exist"))
  end

  test "init/1 raises if path not given" do
    assert_raise(
      ArgumentError,
      "Please pass a :path option contatining the path to the config file.",
      fn -> MUT.init([]) end
    )
  end

  test "aises if path not given" do
    assert_raise(
      ArgumentError,
      "Please pass a :path option contatining the path to the config file.",
      fn -> MUT.call(%Kubereq.Kubeconfig{}, []) end
    )
  end

  test "init/1 raises if unsupported options passed" do
    assert_raise ArgumentError, fn -> MUT.init(foo: :bar) end
  end
end
