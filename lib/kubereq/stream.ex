defmodule Kubereq.Stream do
  @moduledoc false

  require Logger

  @type remainder :: binary()

  @spec create_list_stream(map(), fun()) :: Enumerable.t(map())
  def create_list_stream(body, get_list) do
    Stream.resource(
      fn -> {:init, body} end,
      fn
        {:init, body} ->
          {body["items"], body["metadata"]["continue"]}

        nil ->
          {:halt, :ok}

        continue ->
          case get_list.(continue) do
            {:ok, %{status: 200, body: body}} -> {body["items"], body["metadata"]["continue"]}
            _ -> {:halt, :ok}
          end
      end,
      fn _ -> :ok end
    )
  end
end
