defmodule Kubereq.Client.Watch do
  require Logger

  @type t :: %__MODULE__{
          resource_version: binary(),
          remainder: binary()
        }

  defstruct [:resume_callback, :resource_version, remainder: ""]

  @spec create_stream(Req.Response.t()) :: Enumerable.t(binary())
  def create_stream(resp) do
    Stream.resource(
      fn -> nil end,
      fn _ ->
        case Req.parse_message(resp, receive do: (message -> message)) do
          {:ok, :done} ->
            {:halt, nil}

          {:ok, message} ->
            {Keyword.get_values(message, :data), nil}

          message ->
            Logger.error("Req returned unexpected message: #{inspect(message)}")
            {:halt, nil}
        end
      end,
      &Function.identity/1
    )
  end

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
      {:error, error} ->
        Logger.error(
          "Could not decode JSON - chunk seems to be malformed",
          error: error
        )

        []

      {:ok, object} ->
        [object]
    end
  end
end
