defmodule Kubereq.Step.TLS do
  @moduledoc """
  Pluggable step to derive TLS configuration from the Kubeconfig.
  """

  alias Kubereq.Error.KubeconfError
  alias Kubereq.Error.StepError

  @spec attach(Req.Request.t()) :: Req.Request.t()
  def attach(req) do
    Req.Request.prepend_request_steps(req, kubereq_tls: &call/1)
  end

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(%Req.Request{options: %{kubeconfig: nil}}) do
    raise StepError.new(:kubeconfig_not_loaded)
  end

  def call(req) do
    Kubereq.Utils.add_ssl_opts(
      req,
      tls(req.options.kubeconfig.current_cluster)
    )
  end

  @spec tls(map()) :: keyword()
  defp tls(cluster) do
    [
      cluster["insecure-skip-tls-verify"] && {:verify, :veriy_peer},
      ca_cert!(cluster),
      sni(cluster),
      {:customize_hostname_check, [match_fun: &check_ips_as_dns_id/2]}
    ]
    |> List.flatten()
    |> Enum.filter(& &1)
  end

  @spec ca_cert!(map()) :: {atom(), any()}
  defp ca_cert!(%{"certificate-authority" => ca_cert_path}) do
    {:cacertfile, String.to_charlist(ca_cert_path)}
  end

  defp ca_cert!(%{"certificate-authority-data" => ca_cert_data_b64}) do
    {:ok, cacert_data} = Kubereq.Utils.cert_from_base64(ca_cert_data_b64)

    {:cacerts, [cacert_data]}
  rescue
    _ -> reraise KubeconfError.new(:cert_prep_failed), __STACKTRACE__
  end

  @spec sni(map()) :: {atom(), any()}
  defp sni(%{"tls-server-name" => sni}) do
    {:server_name_indication, sni}
  end

  defp sni(_), do: nil

  # Temporary workaround until this is fixed in some lower layer
  # https://github.com/erlang/otp/issues/7968
  @spec check_ips_as_dns_id({:dns_id}, charlist()) :: true | :default
  defp check_ips_as_dns_id({:dns_id, hostname}, {:iPAddress, ip}) do
    with {:ok, ip_tuple} <- :inet.parse_address(hostname),
         ^ip <- Tuple.to_list(ip_tuple) do
      true
    else
      _ -> :default
    end
  end

  defp check_ips_as_dns_id(_, _), do: :default
end
