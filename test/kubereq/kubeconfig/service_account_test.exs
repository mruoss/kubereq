defmodule Kubereq.Kubeconfig.ServiceAccountTest do
  use ExUnit.Case, async: true

  alias Kubereq.Kubeconfig.ServiceAccount, as: MUT

  test "Imports config from file" do
    path_to_folder = "test/support/kubeconfig/tls"
    kubeconfig = MUT.call(%Kubereq.Kubeconfig{}, MUT.init(path_to_folder: path_to_folder))

    assert 1 === length(kubeconfig.clusters)
    cluster = List.first(kubeconfig.clusters)
    assert "default" === cluster["name"]
    assert "#{path_to_folder}/ca.crt" === cluster["cluster"]["certificate-authority"]
    assert 1 === length(kubeconfig.users)
    user = List.first(kubeconfig.users)
    assert "default" === user["name"]
    assert "#{path_to_folder}/token" === user["user"]["tokenFile"]

    assert 1 === length(kubeconfig.contexts)
    context = List.first(kubeconfig.contexts)
    assert "default" === context["name"]
    assert "foo-namespace" === context["context"]["namespace"]
  end

  test "raises if file not found but only if !: true" do
    assert_raise ArgumentError, fn ->
      MUT.call(%Kubereq.Kubeconfig{}, MUT.init(path_to_folder: "/does/not/exist", !: true))
    end

    _kubeconfig = MUT.call(%Kubereq.Kubeconfig{}, MUT.init(path_to_folder: "/does/not/exist"))
  end

  test "init/1 raises if unsupported options passed" do
    assert_raise ArgumentError, fn -> MUT.init(foo: :bar) end
  end
end
