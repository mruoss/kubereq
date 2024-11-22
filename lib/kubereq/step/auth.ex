defmodule Kubereq.Step.Auth do
  @moduledoc false

  alias Kubereq.Auth.Exec
  alias Kubereq.Error.StepError

  @spec call(req :: Req.Request.t()) :: Req.Request.t() | {Req.Request.t(), StepError.t()}
  def call(req), do: auth(req, req.options.kubeconfig.current_user)

  @spec auth(Req.Request.t(), map()) :: Req.Request.t()
  defp auth(req, %{"client-certificate" => certfile, "client-key" => keyfile}) do
    Kubereq.Utils.add_ssl_opts(req,
      certfile: certfile,
      keyfile: keyfile
    )
  end

  defp auth(req, %{
         "client-certificate-data" => cert_data_b64,
         "client-key-data" => key_data_b64
       }) do
    {:ok, cert} = Kubereq.Utils.cert_from_base64(cert_data_b64)
    {:ok, key} = Kubereq.Utils.key_from_base64(key_data_b64)

    Kubereq.Utils.add_ssl_opts(req, cert: cert, key: key)
  end

  defp auth(req, %{"token" => token}) do
    Req.Request.merge_options(req, auth: {:bearer, token})
  end

  defp auth(req, %{"tokenFile" => token_file}) do
    Req.Request.merge_options(req, auth: {:bearer, File.read!(token_file)})
  end

  defp auth(req, %{"username" => username, "password" => password}) do
    Req.Request.merge_options(req, auth: {:basic, "#{username}:#{password}"})
  end

  defp auth(req, %{"exec" => config}) do
    case Exec.run(config) do
      {:ok, exec_credential_status} ->
        aggregate_req(req, exec_credential_status)

      {:error, error} ->
        {req, error}
    end
  end

  defp auth(req, _), do: req

  @spec aggregate_req(Req.Request.t(), map()) :: Req.Request.t()
  defp aggregate_req(req, %{"token" => _} = status) when is_map_key(status, "token") do
    %{"token" => token} = status

    req
    |> Req.Request.merge_options(auth: {:bearer, token})
    |> aggregate_req(Map.delete(status, "token"))
  end

  defp aggregate_req(req, status)
       when is_map_key(status, "clientCertificateData") and is_map_key(status, "clientKeyData") do
    %{"clientCertificateData" => cert_data_b64, "clientKeyData" => key_data_b64} = status
    {:ok, cert} = Kubereq.Utils.cert_from_pem(cert_data_b64)
    {:ok, key} = Kubereq.Utils.key_from_pem(key_data_b64)

    req
    |> Kubereq.Utils.add_ssl_opts(cert: cert, key: key)
    |> aggregate_req(Map.drop(status, ["clientCertificateData", "clientKeyData"]))
  end

  defp aggregate_req(req, _status), do: req
end
