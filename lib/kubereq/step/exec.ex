defmodule Kubereq.Step.Exec do
  @moduledoc """
  Req step to configure Kubeconfig `exec` authentication.
  See: https://kubernetes.io/docs/reference/config-api/kubeconfig.v1/#ExecConfig
  """

  alias Kubereq.Error.KubeconfError

  use GenServer

  @type exec_config :: map()
  @type exec_credential :: map()

  @type t :: %__MODULE__{
          exec_config: exec_config(),
          exec_credential: exec_credential()
        }

  defstruct [:exec_config, exec_credential: nil]

  @spec attach(Req.Request.t()) :: Req.Request.t()
  def attach(req) do
    req
    |> Req.Request.register_options([:exec_auth])
    |> Req.Request.prepend_request_steps(exec: &call/1)
  end

  @spec call(Req.Request.t()) :: Req.Request.t()
  def call(%Req.Request{options: %{exec_auth: config}} = req) do
    {:ok, exec_credential_status} =
      GenServer.call(config[:pid], :exec_credential_status, :infinity)

    relevant_status_info = Map.delete(exec_credential_status, "expirationTimestamp")

    req
    |> aggregate_req(relevant_status_info)
  end

  def call(req), do: req

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

      raise error
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

  @spec format_env(env :: map() | nil) :: [{String.t(), String.t()}]
  defp format_env(nil), do: []

  defp format_env(env) do
    for %{"name" => name, "value" => value} <- env, do: {name, value}
  end

  @spec aggregate_req(Req.Request.t(), map()) :: Req.Request.t()
  defp aggregate_req(req, %{"token" => token} = status) do
    req
    |> Req.Request.merge_options(auth: {:bearer, token})
    |> aggregate_req(Map.delete(status, "token"))
  end

  defp aggregate_req(
         req,
         %{"clientCertificateData" => cert_data_b64, "clientKeyData" => key_data_b64} = status
       ) do
    {:ok, cert} = Kubereq.Cert.cert_from_base64(cert_data_b64)
    {:ok, key} = Kubereq.Cert.key_from_base64(key_data_b64)

    req
    |> Kubereq.Client.add_ssl_opts(cert: cert, key: key)
    |> aggregate_req(Map.drop(status, ["clientCertificateData", "clientKeyData"]))
  end

  defp aggregate_req(req, _status), do: req
end
