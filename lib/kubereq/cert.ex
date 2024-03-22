defmodule Kubereq.Cert do
  @private_key_atoms [
    :RSAPrivateKey,
    :DSAPrivateKey,
    :ECPrivateKey,
    :PrivateKeyInfo
  ]

  def cert_from_base64(cert_data_b64) do
    cert_data_b64
    |> Base.decode64!()
    |> :public_key.pem_decode()
    |> Enum.find_value(fn {:Certificate, data, _} -> {:ok, data} end)
  end

  def key_from_base64(key_data_b64) do
    key_data_b64
    |> Base.decode64!()
    |> :public_key.pem_decode()
    |> Enum.find_value(fn
      {type, data, _} when type in @private_key_atoms -> {:ok, {type, data}}
    end)
  end
end
