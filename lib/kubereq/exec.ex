defmodule Kubereq.Exec do
  @moduledoc false

  alias Kubereq.Error.KubeconfError

  use GenServer

  @type exec_config :: map()
  @type exec_credential :: map()

  @type t :: %__MODULE__{
          exec_config: exec_config(),
          exec_credential: exec_credential()
        }

  defstruct [:exec_config, exec_credential: nil]

  def run(config) do
    config_hash = :erlang.phash2(config)

    server =
      case Registry.lookup(__MODULE__, config_hash) do
        [] ->
          name = {:via, Registry, {__MODULE__, config_hash}}
          {:ok, pid} = start_link(config, name: name)
          pid

        [{pid, _}] ->
          pid
      end

    GenServer.call(server, :exec_credential_status, :infinity)
  end

  @spec start_link(exec_config(), opts :: keyword()) :: GenServer.on_start()
  def start_link(exec_config, opts) do
    GenServer.start_link(__MODULE__, exec_config, opts)
  end

  @impl GenServer
  def init(exec_config) do
    {:ok, %__MODULE__{exec_config: exec_config}}
  end

  @impl GenServer
  def handle_call(:exec_credential_status, _from, state) do
    if credentials_valid?(state) do
      {:reply, {:ok, state.exec_credential["status"]}, state}
    else
      case exec(state.exec_config) do
        {:ok, exec_credential} ->
          {:reply, {:ok, exec_credential["status"]},
           struct!(state, exec_credential: exec_credential)}

        {:error, error} ->
          {:reply, {:error, error}, state}
      end
    end
  end

  @spec credentials_valid?(t()) :: boolean()
  defp credentials_valid?(state) do
    case get_in(state.exec_credential, ["status", "expirationTimestamp"]) do
      nil ->
        false

      timestamp ->
        {:ok, expiration_timestamp, _} = DateTime.from_iso8601(timestamp)
        DateTime.compare(expiration_timestamp, DateTime.utc_now()) == :gt
    end
  end

  @spec exec(config :: exec_config()) :: {:ok, exec_credential()} | {:error, KubeconfError.t()}
  defp exec(config) do
    {raw_result, _} =
      System.cmd(
        config["command"],
        List.wrap(config["args"]),
        env: format_env(config["env"])
      )

    parse_result(raw_result)
  rescue
    error in ErlangError ->
      if error.reason == :enoent,
        do: IO.puts(config["installHint"] || "Command #{config["command"]} was not found")

      reraise error, __STACKTRACE__
  end

  @spec parse_result(raw_result :: String.t()) ::
          {:ok, exec_credential()} | {:error, KubeconfError.t()}
  defp parse_result(raw_result) do
    case YamlElixir.read_from_string(raw_result) do
      {:ok, contents} ->
        {:ok, contents}

      {:error, error} ->
        {:error, KubeconfError.new(:exec_conf_decode_failed, error)}
    end
  end

  @spec format_env(env :: map()) :: [{String.t(), String.t()}]

  defp format_env(env) do
    for %{"name" => name, "value" => value} <- env, do: {name, value}
  end
end
