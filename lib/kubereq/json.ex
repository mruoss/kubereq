defmodule Kubereq.JSON do
  @moduledoc false

  cond do
    Code.ensure_loaded?(JSON) ->
      defdelegate decode!(binary), to: JSON
      defdelegate decode(binary), to: JSON

    Code.ensure_loaded?(Jason) ->
      defdelegate decode!(binary), to: Jason
      defdelegate decode(binary), to: Jason
  end
end
