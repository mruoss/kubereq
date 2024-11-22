defmodule KubereqIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  import YamlElixir.Sigil

  @cluster_name "kubereq"
  @kubeconfig_path "test/support/kubeconfig-integration.yaml"
  @namespace "integrationtest"

  setup_all do
    {clusters, 0} = System.cmd("kind", ~w(get clusters))

    if @cluster_name not in String.split(clusters, "\n", trim: true) do
      Mix.Shell.IO.info("Creating kind cluster #{@cluster_name}")
      0 = Mix.Shell.IO.cmd("kind create cluster --name #{@cluster_name} ")
    end

    if not File.exists?(@kubeconfig_path) do
      Mix.Shell.IO.info("Generating kubeconfig file: #{@kubeconfig_path}")

      0 =
        Mix.Shell.IO.cmd(
          ~s(kind export kubeconfig --kubeconfig "#{@kubeconfig_path}" --name "#{@cluster_name}")
        )
    end

    kubeconf = {Kubereq.Kubeconfig.File, path: "test/support/kubeconfig-integration.yaml"}

    req_ns =
      Req.new() |> Kubereq.attach(kubeconfig: kubeconf, api_version: "v1", kind: "Namespace")

    req_pod =
      Req.new() |> Kubereq.attach(kubeconfig: kubeconf, api_version: "v1", kind: "Pod")

    req_cm =
      Req.new() |> Kubereq.attach(kubeconfig: kubeconf, api_version: "v1", kind: "ConfigMap")

    {:ok, _} =
      Kubereq.apply(req_ns, ~y"""
      apiVersion: v1
      kind: Namespace
      metadata:
        name: #{@namespace}
      """)

    [
      req_cm: req_cm,
      req_ns: req_ns,
      req_pod: req_pod,
      kubeconfig: kubeconf
    ]
  end

  setup %{req_cm: req_cm, req_pod: req_pod} do
    test_id = :rand.uniform(10_000)

    example_config_1 = ~y"""
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: example-config-1-#{:rand.uniform(10_000)}
      namespace: #{@namespace}
      labels:
        test: kubereq-#{test_id}
        app: kubereq
    data:
      foo: bar
    """

    example_config_2 = ~y"""
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: example-config-2-#{:rand.uniform(10000)}
      namespace: #{@namespace}
      labels:
        test: kubereq-#{test_id}
        app: kubereq
    data:
      foo: bar
    """

    on_exit(fn ->
      Kubereq.delete_all(req_cm, @namespace, label_selectors: [{"app", "kubereq"}])
      Kubereq.delete_all(req_pod, @namespace, label_selectors: [{"app", "kubereq"}])
    end)

    [example_config_1: example_config_1, example_config_2: example_config_2, test_id: test_id]
  end

  test "basic CRUD", %{req_cm: req, example_config_1: example_config_1} do
    {:ok, resp} = Kubereq.create(req, example_config_1)
    assert 201 == resp.status

    {:ok, resp} = Kubereq.update(req, put_in(example_config_1, ~w(data foo), "baz"))
    assert 200 == resp.status
    assert "baz" == get_in(resp.body, ~w"data foo")

    result =
      Kubereq.wait_until(req, @namespace, example_config_1["metadata"]["name"], fn cm ->
        "baz" == get_in(cm, ~w"data foo")
      end)

    assert :ok == result

    {:ok, resp} = Kubereq.get(req, @namespace, example_config_1["metadata"]["name"])
    assert 200 = resp.status
    assert "baz" == get_in(resp.body, ~w"data foo")

    Kubereq.delete(req, @namespace, example_config_1["metadata"]["name"])
    assert 200 = resp.status

    result =
      Kubereq.wait_until(
        req,
        @namespace,
        example_config_1["metadata"]["name"],
        &(&1 == :deleted)
      )

    assert :ok == result
  end

  test "Apply subresource", %{req_ns: req_ns} do
    ns = ~y"""
      apiVersion: v1
      kind: Namespace
      metadata:
        name: #{@namespace}
      status:
        phase: Active
    """

    {:ok, resp} = Kubereq.apply(req_ns, ns, subresource: "status")
    assert 200 = resp.status
  end

  test "Wait until returns error when deleted", %{req_cm: req, example_config_1: example_config_1} do
    {:ok, resp} = Kubereq.create(req, example_config_1)
    assert 201 == resp.status

    {:ok, resp} = Kubereq.delete(req, @namespace, example_config_1["metadata"]["name"])
    assert 200 = resp.status

    result =
      Kubereq.wait_until(
        req,
        @namespace,
        example_config_1["metadata"]["name"],
        fn
          :deleted -> {:error, "Deleted"}
          _ -> false
        end
      )

    assert {:error, "Deleted"} == result
  end

  test "List resources", %{
    req_cm: req,
    example_config_1: example_config_1,
    example_config_2: example_config_2,
    test_id: test_id
  } do
    {:ok, _resp} = Kubereq.create(req, example_config_1)
    {:ok, _resp} = Kubereq.create(req, example_config_2)
    {:ok, resp} = Kubereq.list(req, @namespace, label_selectors: "test=kubereq-#{test_id}")

    items = resp.body["items"]
    assert is_list(items)
    assert 2 = length(items)
    resource_names = Enum.map(items, & &1["metadata"]["name"])
    assert example_config_1["metadata"]["name"] in resource_names
    assert example_config_2["metadata"]["name"] in resource_names
  end

  test "JSON patch", %{req_cm: req, example_config_1: example_config_1} do
    {:ok, resp} = Kubereq.create(req, example_config_1)
    assert "bar" == resp.body["data"]["foo"]

    json_patch = [%{"op" => "replace", "path" => "/data/foo", "value" => "baz"}]

    {:ok, resp} =
      Kubereq.json_patch(req, json_patch, @namespace, example_config_1["metadata"]["name"])

    assert "baz" == resp.body["data"]["foo"]

    result =
      Kubereq.wait_until(req, @namespace, example_config_1["metadata"]["name"], fn cm ->
        "baz" == get_in(cm, ~w"data foo")
      end)

    assert :ok == result
  end

  test "Merge patch", %{req_cm: req, example_config_1: example_config_1} do
    {:ok, resp} = Kubereq.create(req, example_config_1)
    assert "bar" == resp.body["data"]["foo"]

    merge_patch = %{"data" => %{"foo" => "baz"}}

    {:ok, resp} =
      Kubereq.merge_patch(req, merge_patch, @namespace, example_config_1["metadata"]["name"])

    assert "baz" == resp.body["data"]["foo"]

    result =
      Kubereq.wait_until(req, @namespace, example_config_1["metadata"]["name"], fn cm ->
        "baz" == get_in(cm, ~w"data foo")
      end)

    assert :ok == result
  end

  test "Watch all resources of a kind in a namespace", %{
    req_cm: req,
    example_config_1: example_config_1
  } do
    cm_name = example_config_1["metadata"]["name"]
    ref = make_ref()
    Kubereq.watch(req, @namespace, stream_to: {self(), ref})

    # Give the async watcher process time to start:
    Process.sleep(10)

    {:ok, %{status: 201}} = Kubereq.create(req, example_config_1)
    {:ok, %{status: 200}} = Kubereq.update(req, put_in(example_config_1, ~w(data foo), "baz"))
    {:ok, %{status: 200}} = Kubereq.delete(req, @namespace, cm_name)

    assert_receive {^ref,
                    %{"type" => "ADDED", "object" => %{"metadata" => %{"name" => ^cm_name}}}}

    assert_receive {^ref,
                    %{"type" => "MODIFIED", "object" => %{"metadata" => %{"name" => ^cm_name}}}}

    assert_receive {^ref,
                    %{"type" => "DELETED", "object" => %{"metadata" => %{"name" => ^cm_name}}}}
  end

  test "Watch a single resource of a kind in a namespace", %{
    req_cm: req,
    example_config_1: example_config_1
  } do
    cm_name = example_config_1["metadata"]["name"]
    ref = make_ref()
    Kubereq.watch_single(req, @namespace, cm_name, stream_to: {self(), ref})

    # Give the async watcher process time to start:
    Process.sleep(10)

    {:ok, %{status: 201}} = Kubereq.create(req, example_config_1)
    {:ok, %{status: 200}} = Kubereq.update(req, put_in(example_config_1, ~w(data foo), "baz"))
    {:ok, %{status: 200}} = Kubereq.delete(req, @namespace, cm_name)

    assert_receive {^ref,
                    %{"type" => "ADDED", "object" => %{"metadata" => %{"name" => ^cm_name}}}}

    assert_receive {^ref,
                    %{"type" => "MODIFIED", "object" => %{"metadata" => %{"name" => ^cm_name}}}}

    assert_receive {^ref,
                    %{"type" => "DELETED", "object" => %{"metadata" => %{"name" => ^cm_name}}}}
  end

  test "receives pod logs synchronously from pod container", %{req_pod: req} do
    pod_name = "example-pod-#{:rand.uniform(10_000)}"
    log_stmt = "foo bar"

    pod = ~y"""
    apiVersion: v1
    kind: Pod
    metadata:
      namespace: #{@namespace}
      name: #{pod_name}
      labels:
        app: kubereq
    spec:
      containers:
        - name: main
          image: busybox
          command:
            - /bin/sh
            - "-c"
            - 'echo "#{log_stmt}"'
            - "sleep infinity"
    """

    Kubereq.apply(req, pod)

    :ok =
      Kubereq.wait_until(req, @namespace, pod_name, &(&1["status"]["phase"] == "Running"),
        timeout: :timer.minutes(2)
      )

    {:ok, resp} = Kubereq.logs(req, @namespace, pod_name)

    stdout =
      resp.body
      |> Enum.reduce("", fn {:stdout, out}, acc -> [acc, out] end)
      |> IO.iodata_to_binary()

    assert stdout =~ "#{log_stmt}\n"
  end

  test "streams pod logs to process", %{req_pod: req} do
    pod_name = "example-pod-#{:rand.uniform(10_000)}"
    log_stmt = "foo bar"

    pod = ~y"""
    apiVersion: v1
    kind: Pod
    metadata:
      namespace: #{@namespace}
      name: #{pod_name}
      labels:
        app: kubereq
    spec:
      containers:
        - name: main
          image: busybox
          command:
            - /bin/sh
            - "-c"
            - 'echo "#{log_stmt}"'
            - "sleep infinity"
    """

    Kubereq.apply(req, pod)

    :ok =
      Kubereq.wait_until(req, @namespace, pod_name, &(&1["status"]["phase"] == "Running"),
        timeout: :timer.minutes(2)
      )

    ref = make_ref()

    {:ok, _pid} =
      Kubereq.PodLogs.start_link(
        req: req,
        namespace: @namespace,
        name: pod_name,
        into: {self(), ref}
      )

    logs =
      Stream.repeatedly(fn -> :ok end)
      |> Enum.reduce_while("", fn _, acc ->
        receive do
          {^ref, :stdout, text} -> {:cont, [acc, text]}
          {:close, 1_000, ""} -> {:halt, acc}
          _ -> {:cont, acc}
        after
          500 -> {:halt, acc}
        end
      end)

    assert logs == ""
  end

  test "sends exec commands to pod and returns stdout", %{req_pod: req} do
    pod_name = "example-pod-#{:rand.uniform(10_000)}"

    pod = ~y"""
    apiVersion: v1
    kind: Pod
    metadata:
      namespace: #{@namespace}
      name: #{pod_name}
      labels:
        app: kubereq
    spec:
      containers:
        - name: main
          image: busybox
          command:
            - /bin/sh
            - "-c"
            - "sleep infinity"
    """

    Kubereq.apply(req, pod)

    :ok =
      Kubereq.wait_until(req, @namespace, pod_name, &(&1["status"]["phase"] == "Running"),
        timeout: :timer.minutes(2)
      )

    {:ok, resp} =
      Kubereq.exec(req, @namespace, pod_name,
        command: "echo",
        command: "foo",
        stdout: true
      )

    stdout =
      resp.body
      |> Enum.reduce("", fn {:stdout, out}, acc -> [acc, out] end)
      |> IO.iodata_to_binary()

    assert stdout == "foo\n"
  end

  test "streams exec commands to pod and prompts back to process", %{req_pod: req} do
    pod_name = "example-pod-#{:rand.uniform(10_000)}"

    pod = ~y"""
    apiVersion: v1
    kind: Pod
    metadata:
      namespace: #{@namespace}
      name: #{pod_name}
      labels:
        app: kubereq
    spec:
      containers:
        - name: main
          image: busybox
          command:
            - /bin/sh
            - "-c"
            - "sleep infinity"
    """

    Kubereq.apply(req, pod)

    :ok =
      Kubereq.wait_until(req, @namespace, pod_name, &(&1["status"]["phase"] == "Running"),
        timeout: :timer.minutes(2)
      )

    ref = make_ref()

    {:ok, pid} =
      Kubereq.PodExec.start_link(
        req: req,
        namespace: @namespace,
        name: pod_name,
        into: {self(), ref},
        tty: true,
        command: "/bin/sh"
      )

    assert_receive {^ref, :connected}
    Kubereq.PodExec.send_stdin(pid, ~s(echo "foo bar"\n))

    result = receive_loop(ref, pid, "") |> IO.iodata_to_binary()
    assert result == ~s(/ # echo "foo bar"\r\nfoo bar\r\n/ # )
  end

  defp receive_loop(ref, dest, acc) do
    receive do
      {^ref, {:stdout, data}} -> receive_loop(ref, dest, [acc, data])
    after
      500 ->
        Kubereq.PodExec.close(dest)
        acc
    end
  end
end
