defmodule Kubereq.Watch do
  @moduledoc false

  require Logger

  @type t :: %__MODULE__{
          resource_version: binary(),
          remainder: binary()
        }

  defstruct [:resume_callback, :resource_version, remainder: ""]

  @spec transform_to_objects(Enumerable.t(binary())) :: Enumerable.t(map())
  def transform_to_objects(stream) do
    stream
    |> Stream.transform(%__MODULE__{}, &chunks_to_lines/2)
    |> Stream.flat_map(&lines_to_json_objects/1)
  end

  @spec chunks_to_lines(binary(), t()) :: {Enumerable.t(binary()), t()}
  defp chunks_to_lines(chunk, state) do
    {remainder, whole_lines} =
      (state.remainder <> chunk)
      |> String.split("\n")
      |> List.pop_at(-1)

    {whole_lines, Map.put(state, :remainder, remainder)}
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
