defmodule Kubereq.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_start_type, _start_args) do
    children = [
      {Registry, keys: :unique, name: Kubereq.Exec},
      Kubereq.Websocket.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Kubereq.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
