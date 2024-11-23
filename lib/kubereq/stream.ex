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

  @spec transform_to_objects(Enumerable.t(binary())) :: Enumerable.t(map())
  def transform_to_objects(stream) do
    stream
    |> Stream.transform("", &chunks_to_lines/2)
    |> Stream.flat_map(&lines_to_json_objects/1)
  end

  @spec chunks_to_lines(binary(), remainder()) :: {Enumerable.t(binary()), t()}
  defp chunks_to_lines(chunk, remainder) do
    {remainder, whole_lines} =
      (remainder <> chunk)
      |> String.split("\n")
      |> List.pop_at(-1)

    {whole_lines, remainder}
  end

  @spec lines_to_json_objects(binary()) :: [map()]
  defp lines_to_json_objects(line) do
    case Jason.decode(line) do
      {:error, _error} ->
        Logger.error("Could not decode JSON - chunk seems to be malformed")
        []

      {:ok, object} ->
        [object]
    end
  end
end
