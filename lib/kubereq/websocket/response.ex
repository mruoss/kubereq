defmodule Kubereq.Websocket.Response do
  @moduledoc """
  Represents a response of a websocket request.
  """
  alias Kubereq.Websocket.Adapter

  @type t :: %__MODULE__{registry_key: reference()}

  defstruct [:registry_key]

  @spec send_message(
          response :: t(),
          message :: Adapter.outgoing_message(),
          timeout :: non_neg_integer()
        ) :: :ok | {:error, term()}
  def send_message(_response, message, timeout \\ 5_000)

  def send_message(_response, message, timeout) when timeout <= 0 do
    {:error, %RuntimeError{message: "Could not send message #{inspect(message)} to websocket."}}
  end

  def send_message(response, message, timeout) do
    with [{server, _}] <-
           Registry.lookup(Kubereq.Websocket.Adapter.Registry, response.registry_key),
         true <- Process.alive?(server) do
      GenServer.call(server, {:send, message})
    else
      _ ->
        Process.sleep(100)
        send_message(response, message, timeout - 100)
    end
  end
end
