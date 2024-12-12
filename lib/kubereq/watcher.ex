defmodule Kubereq.Watcher do
  @moduledoc """
  A behaviour module for implementing a Kubernetes watch event handler.

  Establishes a watch connection for [efficient detection of changes]
  [k8s-watch-concept]. All events are passed to `c:handle_event/3`.

  [k8s-watch-concept]: https://kubernetes.io/docs/reference/using-api/api-concepts/#efficient-detection-of-changes

  ```mermaid
  sequenceDiagram
      participant Watcher
      participant K8s as K8s API Server

      Watcher->>K8s: ?watch=true

      loop K8s Detects Changes
        K8s ->> Watcher: {:created, %{"kind" => "Pod"}}
        K8s ->> Watcher: {:modified, %{"kind" => "Pod"}}
        K8s ->> Watcher: {:deleted, %{"kind" => "Pod"}}
      end

  ```

  ### Example

  When started, `Kubereq.Watcher` establishes a watch connection to the API
  Server.

  For every watch event, `c:handle_event/3` is then called with the `t:type`,
  `object` and `state`.

      defmodule PodEventHandler do
        use Kubereq.Watcher

        require Logger

        def start_link(init_arg) do
          req = Keyword.fetch!(init_arg, :req)
          naemspace = Keyword.get(opts, :namespace)

          Kubereq.Watcher.start_link(__MODULE__, req, namespace, api_version: "v1", kind: "Pod")
        end

        @impl Kubereq.Watcher
        def init(init_arg) do
          initial_state = %{}
          {:ok, initial_state}
        end

        @impl Kubereq.Watcher
        def handle_event(:created, pod, state) do
          Logger.debug("Pod \#{pod["metadata"]["name"]} was created.")
          {:noreply, state}
        end

        @impl Kubereq.Watcher
        def handle_event(:modified, pod, state) do
          Logger.debug("Pod \#{pod["metadata"]["name"]} was modified.")
          {:noreply, state}
        end

        @impl Kubereq.Watcher
        def handle_event(:deleted, pod, state) do
          Logger.debug("Pod \#{pod["metadata"]["name"]} was deleted.")
          {:noreply, state}
        end
      end

  """
  use GenServer

  require Logger

  @type event_type :: :created | :modified | :deleted

  @doc """
  Called when the server is started but before connection is establised.
  """
  @callback init(init_arg :: term()) :: {:ok, state :: any()} | {:stop, reason :: any()}

  @doc """
  Called for every event detected for the resources watched on the Kubernetes
  cluster. It is passed the `t:event_type` (one of `:created`, `:modified` or
  `:deleted`), the `object` (resource) the event occurred on and the current
    `state`.
  """
  @callback handle_event(event_type :: event_type(), object :: map(), state :: term()) ::
              {:noreply, new_state}
              | {:noreply, new_state, timeout()}
              | {:stop, reason, new_state}
            when new_state: term(), reason: term()

  @doc """
  Similar to GenServer's `c:GenServer.handle_info/2`, called for messages sent
  to the process.
  """
  @callback handle_info(msg :: :timeout | term(), state :: term()) ::
              {:noreply, new_state}
              | {:noreply, new_state,
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, reason, new_state}
            when new_state: term(), reason: term()

  @doc """
  Similar to GenServer's `c:GenServer.terminate/2`, called then the watcher is
  terminated.
  """
  @callback terminate(reason, state :: term()) :: term()
            when reason: :normal | :shutdown | {:shutdown, term()} | term()

  defstruct [
    :module,
    :req,
    :req_opts,
    :namespace,
    :mint_ref,
    :user_state,
    :resource_version,
    remainder: ""
  ]

  defmacro __using__(opts) do
    quote do
      @behaviour Kubereq.Watcher

      unless Module.has_attribute?(__MODULE__, :doc) do
        @doc """
        Returns a specification to start this module under a supervisor.

        See `Supervisor`.
        """
      end

      def child_spec(init_arg) do
        default = %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [init_arg]}
        }

        Supervisor.child_spec(default, unquote(Macro.escape(opts)))
      end

      defoverridable child_spec: 1

      @doc false
      def init(_init_arg), do: {:ok, nil}

      @doc false
      def handle_info(msg, state) do
        proc =
          case Process.info(self(), :registered_name) do
            {_, []} -> self()
            {_, name} -> name
          end

        :logger.error(
          %{
            label: {GenServer, :no_handle_info},
            report: %{
              module: __MODULE__,
              message: msg,
              name: proc
            }
          },
          %{
            domain: [:otp, :elixir],
            error_logger: %{tag: :error_msg},
            report_cb: &GenServer.format_report/1
          }
        )

        {:noreply, state}
      end

      @doc false
      def terminate(_reason, _state), do: :ok

      # Allow overriding handle_event
      defoverridable init: 1, handle_info: 2, terminate: 2
    end
  end

  @doc """
  Starts a watcher process linked to the current process.

  Once the watcher is started, the `c:init/1` function of the given module is
  called. After that, the watch connection is established.

  ### Arguments

  `req`, `namespace` and `init_arg` are forwarded to `connect/3`.
  """
  def start_link(module, req, namespace \\ nil, opts \\ [], init_arg \\ []) do
    GenServer.start_link(Kubereq.Watcher, %{
      module: module,
      namespace: namespace,
      req: req,
      opts: opts,
      init_arg: init_arg
    })
  end

  @impl true
  def init(%{module: module, namespace: namespace, req: req, opts: opts, init_arg: init_arg}) do
    result = module.init(init_arg)

    case Kubereq.Watcher.connect(req, namespace, opts) do
      {:ok, %{status: 200} = resp} ->
        state =
          struct!(__MODULE__,
            module: module,
            req: req,
            namespace: namespace,
            mint_ref: resp.body.ref
          )

        process_result(result, state, :ok)

      {:error, error} ->
        {:stop, error}

      {:ok, %{status: status}} ->
        {:stop, "Failed to establish connection: HTTP Status #{status}"}
    end
  end

  @doc """
  Establish a watch connection to the API Server for the given `req`.
  If `namespace` is nil, all namespaces are watched.

  ### Options

  All options described in `Kubereq`'s moduledoc plus:

    * `:resource_version` - Optional. Resource version to start watching from.
      Per default, the watcher starts watching from the current
      resource_version.
  """
  def connect(req, namespace, opts \\ []) do
    {resource_version, opts} =
      Keyword.pop_lazy(opts, :resource_version, fn ->
        case Req.request(req, operation: :list, path_params: [namespace: namespace]) do
          {:ok, %{status: 200, body: body}} ->
            body["metadata"]["resourceVersion"]

          {:error, error} ->
            Logger.warning(
              "Failed determining resource version; setting it to 0. #{Exception.message(error)}"
            )

            "0"

          {:ok, %{status: status}} ->
            Logger.warning(
              "Got HTTP status #{status} while trying to determine resource version; setting it to 0. "
            )

            "0"
        end
      end)

    req =
      req
      |> Req.merge(
        operation: :watch,
        path_params: [namespace: namespace],
        params: [resourceVersion: resource_version],
        into: :self,
        receive_timeout: :infinity
      )
      |> Req.merge(opts)

    Req.request(req)
  end

  @impl true
  def handle_continue(continue_arg, state) do
    state.module.handle_continue(continue_arg, state.user_state)
  end

  @impl true
  def handle_info({ref, chunk}, %{mint_ref: ref} = state) do
    handle_chunk(chunk, state)
  end

  def handle_info(message, state) do
    state.module.handle_info(message, state.user_state)
    |> process_result(state, :noreply)
  end

  defp process_result(result, state, ok_atom) do
    case result do
      {^ok_atom, new_user_state, timeout_continue} ->
        {ok_atom, %{state | user_state: new_user_state}, timeout_continue}

      {^ok_atom, new_user_state} ->
        {ok_atom, %{state | user_state: new_user_state}}

      {:stop, reason, new_user_state} ->
        {:stop, reason, %{state | user_state: new_user_state}}
    end
  end

  @doc false
  def handle_chunk(:done, state) do
    req = Req.merge(state.req, params: [resourceVersion: state.resource_version])

    case connect(req, state.namespace) do
      {:ok, %{status: 200} = resp} ->
        {:noreply, struct(state, mint_ref: resp.body.ref)}

      {:error, error} ->
        {:stop, error, state}
    end
  end

  def handle_chunk({:data, data}, state) do
    {lines, remainder} = chunks_to_lines(data, state.remainder)
    state = %{state | remainder: remainder}

    Enum.reduce_while(lines, {:noreply, state}, fn
      line, acc ->
        # acc = {:noreply, state} or {:noreply, state, timeout}
        state = elem(acc, 1)

        event = Jason.decode!(line)
        state = %{state | resource_version: event["object"]["metdata"]["resourceVersion"]}

        case event |> handle_event(state) |> process_result(state, :noreply) do
          {:stop, _reason, _new_user_state} = result -> {:halt, result}
          result -> {:cont, result}
        end
    end)
  end

  defp handle_event(event, state) do
    %{"type" => type, "object" => object} = event

    case type do
      "ADDED" -> state.module.handle_event(:added, object, state.user_state)
      "MODIFIED" -> state.module.handle_event(:modified, object, state.user_state)
      "DELETED" -> state.module.handle_event(:deleted, object, state.user_state)
      "BOOKMARK" -> {:noreply, state.user_state}
    end
  end

  @doc false
  @spec transform_to_objects(Enumerable.t(binary())) :: Enumerable.t(map())
  def transform_to_objects(stream) do
    stream
    |> Stream.transform("", &chunks_to_lines/2)
    |> Stream.flat_map(&lines_to_json_objects/1)
  end

  @spec chunks_to_lines(binary(), remainder :: binary()) :: {[binary()], binary()}
  defp chunks_to_lines(chunk, remainder) do
    {remainder, whole_lines} =
      (remainder <> chunk)
      |> String.split("\n")
      |> List.pop_at(-1)

    {whole_lines, remainder}
  end

  @spec lines_to_json_objects(binary()) :: [map()]
  defp lines_to_json_objects(line) do
    case Jason.decode(line) do
      {:error, _error} ->
        []

      {:ok, object} ->
        [object]
    end
  end

  @impl true
  def terminate(reason, state) do
    state.module.terminate(reason, state.user_state)
  end
end
