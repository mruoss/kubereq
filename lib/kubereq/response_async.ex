defmodule Kubereq.ResponseAsync do
  # TODO: moduledoc!

  @derive {Inspect, only: []}
  defstruct [:stream_fun, :req, items: [], stream_acc: nil]

  @type stream_acc() :: any()

  @type t() :: %__MODULE__{
          stream_fun: (map(), stream_acc() -> stream_acc()),
          req: Req.Request.t(),
          items: list(),
          stream_acc: stream_acc()
        }

  def new(fields), do: struct!(__MODULE__, fields)

  defimpl Enumerable do
    def count(_async), do: {:error, __MODULE__}

    def member?(_async, _value), do: {:error, __MODULE__}

    def slice(_async), do: {:error, __MODULE__}

    def reduce(_async, {:halt, acc}, _fun) do
      {:halted, acc}
    end

    def reduce(async, {:suspend, acc}, fun) do
      {:suspended, acc, &reduce(async, &1, fun)}
    end

    def reduce(async, {:cont, acc}, fun) when async.items != [] do
      [item | rest] = async.items
      result = fun.(item, acc)
      reduce(%{async | items: rest}, result, fun)
    end

    def reduce(async, {:cont, acc}, fun) do
      case async.stream_fun.(async.req, async.stream_acc) do
        {:ok, items, stream_acc} ->
          reduce(%{async | items: items, stream_acc: stream_acc}, {:cont, acc}, fun)

        :done ->
          {:done, acc}

        {:error, e} ->
          raise e

        other ->
          raise "unexpected message: #{inspect(other)}"
      end
    end
  end
end
