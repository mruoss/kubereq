defmodule Kubereq.JSON do
  @moduledoc false

  cond do
    Code.ensure_loaded?(JSON) ->
      defdelegate decode!(binary), to: JSON
      defdelegate decode(binary), to: JSON

    Code.ensure_loaded?(Jason) ->
      defdelegate decode!(binary), to: Json
      defdelegate decode(binary), to: Json

    true ->
      raise "Please install Jason as a dependency."
  end
end
