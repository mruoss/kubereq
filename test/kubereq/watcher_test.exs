defmodule Kubereq.WatcherTest do
  use ExUnit.Case, async: true
  alias Kubereq.Watcher, as: MUT

  defmodule TestWatcher do
    use MUT

    def start_link(init_arg) do
      {req, init_arg} = Keyword.pop!(init_arg, :req)
      {namespace, init_arg} = Keyword.pop(init_arg, :namespace)
      {opts, init_arg} = Keyword.pop(init_arg, :opts, [])
      MUT.start_link(__MODULE__, req, namespace, opts, init_arg)
    end

    @impl true
    def init(init_arg) do
      dest = Keyword.fetch!(init_arg, :dest)
      ref = Keyword.fetch!(init_arg, :ref)
      Req.Test.allow(:k8s_cluster, dest, self())
      {:ok, %{dest: dest, ref: ref}}
    end

    @impl true
    def handle_event(event_type, object, state) do
      send(state.dest, {state.ref, event_type, object})
      {:noreply, state}
    end

    @impl true
    def handle_info(message, state) do
      send(state.dest, {state.ref, :message, message})
      {:noreply, state}
    end
  end

  setup_all do
    kubeconfig = {Kubereq.Kubeconfig.Stub, plugs: {Req.Test, :k8s_cluster}}
    req = Req.new() |> Kubereq.attach(kind: "ConfigMap", kubeconfig: kubeconfig)
    [req: req]
  end

  setup %{req: req} do
    Req.Test.stub(:k8s_cluster, Kubereq.K8sClusterStub)
    ref = make_ref()

    pid =
      start_link_supervised!({TestWatcher, req: req, dest: self(), ref: ref}, restart: :temporary)

    %{ref: ref, watcher: pid}
  end

  test "calls handle_event/3 callback", %{ref: ref} do
    assert_receive({^ref, :added, _object}, 500, "handle_event/3 wasn't called for type :added.")

    assert_receive(
      {^ref, :modified, _object},
      500,
      "handle_event/3 wasn't called for type :modified."
    )

    assert_receive(
      {^ref, :deleted, _object},
      500,
      "handle_event/3 wasn't called for type :deleted."
    )
  end

  test "calls handle_info/2 upon receiving a message", %{watcher: watcher, ref: ref} do
    send(watcher, :foo)

    assert_receive({^ref, :message, :foo}, 500, "handle_info/2 wasn't called.")
  end
end
