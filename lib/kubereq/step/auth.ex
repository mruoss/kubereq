defmodule Kubereq.Step.Auth do
  @moduledoc """
  Pluggable step to derive Req steps necessary for auth to the cluster.
  """

  alias Kubereq.Error.StepError
  alias Kubereq.Step.Exec

  @spec attach(Req.Request.t()) :: Req.Request.t()
  def attach(req) do
    Req.Request.prepend_request_steps(req, kubereq_auth: &call/1)
  end

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(%Req.Request{options: %{kubeconfig: nil}}) do
    raise StepError.new(:kubeconfig_not_loaded)
  end

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
    # Start Middleware.Exec in dynamic supervisor
    config_hash = :erlang.phash2(config)

    pid =
      case Registry.lookup(Exec, config_hash) do
        [] ->
          name = {:via, Registry, {Exec, config_hash}}
          {:ok, pid} = Exec.start_link(config, name: name)
          pid

        [{pid, _}] ->
          pid
      end

    Req.Request.merge_options(req, exec_pid: pid)
  end

  defp auth(req, _), do: req
end
