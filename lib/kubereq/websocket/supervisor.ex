defmodule Kubereq.Websocket.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_init_arg) do
    children = [
      {DynamicSupervisor, name: Kubereq.Websocket.Adapter, strategy: :one_for_one},
      {Registry, name: Kubereq.Websocket.Adapter.Registry, keys: :unique}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
