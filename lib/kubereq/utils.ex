defmodule Kubereq.Utils do
  @moduledoc false

  @private_key_atoms [
    :RSAPrivateKey,
    :DSAPrivateKey,
    :ECPrivateKey,
    :PrivateKeyInfo
  ]

  @spec add_ssl_opts(Req.Request.t(), keyword()) :: Req.Request.t()
  def add_ssl_opts(req, options) do
    connect_options = List.wrap(req.options[:connect_options])
    transport_opts = List.wrap(connect_options[:transport_opts])
    transport_opts = Keyword.merge(transport_opts, options)
    connect_options = Keyword.merge(connect_options, transport_opts: transport_opts)
    Req.merge(req, connect_options: connect_options)
  end

  @spec cert_from_base64(binary()) :: {:ok, binary()}
  def cert_from_base64(cert_data_b64) do
    cert_data_b64
    |> Base.decode64!()
    |> cert_from_pem()
  end

  @spec key_from_base64(binary()) :: {:ok, {atom(), binary()}}
  def key_from_base64(key_data_b64) do
    key_data_b64
    |> Base.decode64!()
    |> key_from_pem()
  end

  @spec cert_from_pem(binary()) :: {:ok, binary()}
  def cert_from_pem(cert_data) do
    cert_data
    |> :public_key.pem_decode()
    |> Enum.find_value(fn {:Certificate, data, _} -> {:ok, data} end)
  end

  @spec key_from_pem(binary()) :: {:ok, {atom(), binary()}}
  def key_from_pem(cert_data) do
    cert_data
    |> :public_key.pem_decode()
    |> Enum.find_value(fn
      {type, data, _} when type in @private_key_atoms -> {:ok, {type, data}}
    end)
  end
end
