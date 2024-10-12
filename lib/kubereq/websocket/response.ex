defmodule Kubereq.Websocket.Response do
  defstruct [:registry_key]

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
