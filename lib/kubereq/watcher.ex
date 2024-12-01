defmodule Kubereq.Watcher do
  @moduledoc ~S"""
  A behaviour module for implementing a Kubernetes watch event handler.

  ### Example

  When started, `Kubereq.Watcher` establishes a watch connection to the API
  Server. When connected, `c:connected/2` is called which can be compared to the
  GenServer's `c:GenServer.init/1`.

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
        def connected(_resp, _init_arg) do
          initial_state = %{}
          {:ok, initial_state}
        end

        @impl Kubereq.Watcher
        def handle_event(:created, pod, state) do
          Logger.debug("Pod #{pod["metadata"]["name"]} was created.")
          {:ok, state}
        end

        @impl Kubereq.Watcher
        def handle_event(:modified, pod, state) do
          Logger.debug("Pod #{pod["metadata"]["name"]} was modified.")
          {:ok, state}
        end

        @impl Kubereq.Watcher
        def handle_event(:deleted, pod, state) do
          Logger.debug("Pod #{pod["metadata"]["name"]} was deleted.")
          {:ok, state}
        end
      end

  """

  require Logger

  @type event_type :: :created | :modified | :deleted

  @callback connected(resp :: Req.Response.t(), init_arg :: term()) ::
              {:ok, state}
              | {:ok, state, timeout()}
              | {:stop, reason :: any()}
            when state: any()

  @callback handle_event(event_type :: event_type(), watch_event :: map(), state :: term()) ::
              {:ok, new_state}
              | {:ok, new_state, timeout()}
              | {:stop, reason, new_state}
            when new_state: term(), reason: term()

  @callback handle_info(msg :: :timeout | term(), state :: term()) ::
              {:ok, new_state}
              | {:ok, new_state, timeout()}
              | {:stop, reason, new_state}
            when new_state: term(), reason: term()

  @callback terminate(reason, state :: term()) :: term()
            when reason: :normal | :shutdown | {:shutdown, term()} | term()

  defstruct [
    :req,
    :req_opts,
    :namespace,
    :mint_ref,
    :user_state,
    :resource_version,
    timeout: :infinity,
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
      def connected(_resp, _init_arg), do: nil

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

        {:ok, state}
      end

      @doc false
      def terminate(_reason, _state), do: :ok

      # Allow overriding handle_event
      defoverridable connected: 2, handle_info: 2, terminate: 2
    end
  end

  def start_link(module, req, namespace \\ nil, init_arg \\ []) do
    {:ok, spawn_link(fn -> init(module, req, namespace, init_arg) end)}
  end

  defp init(module, req, namespace, init_arg) do
    case Kubereq.Watcher.connect(req, namespace, init_arg) do
      {:ok, %{status: 200} = resp} ->
        state =
          struct(__MODULE__,
            req: req,
            namespace: namespace,
            mint_ref: resp.body.ref
          )

        module.connected(resp, init_arg)
        |> process_result(state, module)

        loop(state, module)

      {:error, error} ->
        exit(error)

      {:ok, %{status: status}} ->
        exit("Failed to establish connection: HTTP Status #{status}")
    end
  end

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

  defp loop(state, module) do
    ref = state.mint_ref
    timeout = state.timeout

    new_state =
      receive do
        {^ref, data} ->
          handle_chunk(module, data, state)

        other ->
          module.handle_info(other, state.user_state)
          |> process_result(state, module)
      after
        timeout ->
          module.handle_info(:timeout, state.user_state)
          |> process_result(state, module)
      end

    loop(new_state, module)
  end

  defp process_result(result, state, module) do
    case result do
      {:ok, new_user_state} ->
        %{state | user_state: new_user_state, timeout: :infinity}

      {:ok, new_user_state, timeout} ->
        %{state | user_state: new_user_state, timeout: timeout}

      {:stop, reason, new_user_state} ->
        module.terminate(reason, new_user_state)
        exit(reason)
    end
  end

  def handle_chunk(module, :done, state) do
    req = Req.merge(state.req, params: [resourceVersion: state.resource_version])

    case connect(req, state.namespace) do
      {:ok, %{status: 200} = resp} ->
        struct(__MODULE__, mint_ref: resp.body.ref)

      {:error, error} ->
        stop(module, error, state.user_state)
    end
  end

  def handle_chunk(module, {:data, data}, state) do
    {lines, remainder} = chunks_to_lines(data, state.remainder)
    state = %{state | remainder: remainder, timeout: :infinity}

    Enum.reduce(lines, state, fn
      line, state ->
        event = Jason.decode!(line)
        state = %{state | resource_version: event["object"]["metdata"]["resourceVersion"]}

        case handle_event(module, event, state.user_state) do
          {:ok, new_user_state} ->
            %{state | user_state: new_user_state}

          {:ok, new_user_state, timeout} ->
            %{state | user_state: new_user_state, timeout: timeout}

          {:stop, reason, new_user_state} ->
            stop(module, reason, new_user_state)
        end
    end)
  end

  defp handle_event(module, event, user_state) do
    %{"type" => type, "object" => object} = event

    case type do
      "ADDED" -> module.handle_event(:added, object, user_state)
      "MODIFIED" -> module.handle_event(:modified, object, user_state)
      "DELETED" -> module.handle_event(:deleted, object, user_state)
      "BOOKMARK" -> {:ok, user_state}
    end
  end

  defp stop(module, reason, user_state) do
    module.terminate(reason, user_state)
    exit(reason)
  end

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
end
