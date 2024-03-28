defmodule Kubereq.Kubeconfig.Access do
  @moduledoc """
  Helper module to access maps in lists.
  """

  @doc ~S"""
  Returns a function that accesses the first element for which `fun` returns a truthy value.

  The returned function is typically passed as an accessor to `Kernel.get_in/2`,
  `Kernel.get_and_update_in/3`, and friends.

  ## Examples

      iex> list = [%{name: "john", salary: 10}, %{name: "francine", salary: 30}]
      iex> get_in(list, [Kubereq.Kubeconfig.Access.find(&(&1.name == "john")), :salary])
      10
      iex> get_and_update_in(list, [Kubereq.Kubeconfig.Access.find(&(&1.name == "john")), :salary], fn prev ->
      ...>   {prev, 15}
      ...> end)
      {10, [%{name: "john", salary: 15}, %{name: "francine", salary: 30}]}

  `find/1` can also be used to pop elements out of a list or
  a key inside of a list:

      iex> list = [%{name: "john", salary: 10}, %{name: "francine", salary: 30}]
      iex> pop_in(list, [Kubereq.Kubeconfig.Access.find(&(&1.name == "francine"))])
      {%{name: "francine", salary: 30}, [%{name: "john", salary: 10}]}
      iex> pop_in(list, [Kubereq.Kubeconfig.Access.find(&(&1.name == "francine")), :name])
      {"francine", [%{salary: 30}, %{name: "john", salary: 10}]}

  When no match is found, the given default is used. This can be used to
  specify defaults and safely traverse missing items.

      iex> list = [%{name: "john", salary: 10}, %{name: "francine", salary: 30}]
      iex> get_in(list, [Kubereq.Kubeconfig.Access.find(&(&1.name == "adam"), %{name: "adam", salary: 50}), :salary])
      50
      iex> get_and_update_in(list, [Kubereq.Kubeconfig.Access.find(&(&1.name == "adam"), %{name: "adam"}), :salary], fn prev ->
      ...>   {prev, 50}
      ...> end)
      {nil, [%{name: "adam", salary: 50}, %{name: "john", salary: 10}, %{name: "francine", salary: 30}]}

  When multiple items exist for which `fun` return a truthy value, the first one is accessed.

      iex> list = [%{name: "john", salary: 10}, %{name: "john", salary: 30}]
      iex> get_in(list, [Kubereq.Kubeconfig.Access.find(&(&1.name == "john")), :salary])
      10

  An error is raised if the accessed structure is not a list:

      iex> get_in(%{}, [Kubereq.Kubeconfig.Access.find(&(&1.name == "john"))])
      ** (RuntimeError) Kubereq.Kubeconfig.Access.find/1 expected a list, got: %{}

  """
  @spec find((term -> boolean), term()) :: Access.access_fun(data :: list, current_value :: list)
  def find(func, default \\ nil) when is_function(func) do
    fn op, data, next -> find(op, data, func, default, next) end
  end

  defp find(:get, data, func, default, next) when is_list(data) do
    data |> Enum.find(default, func) |> next.()
  end

  defp find(:get_and_update, data, func, default, next) when is_list(data) do
    get_and_update_find(data, func, next, default, false)
  end

  defp find(_op, data, _default, _func, _next) do
    raise "Kubereq.Kubeconfig.Access.find/1 expected a list, got: #{inspect(data)}"
  end

  @doc ~S"""
  Returns a function that accesses the first element for which `fun` returns a truthy value.

  The returned function is typically passed as an accessor to `Kernel.get_in/2`,
  `Kernel.get_and_update_in/3`, and friends.

  Similar to find/2, but the returned function raises if the no item is found for which `fun` returns a truthy value.

  ## Examples

      iex> list = [%{name: "john", salary: 10}, %{name: "francine", salary: 30}]
      iex> get_in(list, [Kubereq.Kubeconfig.Access.find!(&(&1.name == "john")), :salary])
      10
      iex> get_and_update_in(list, [Kubereq.Kubeconfig.Access.find!(&(&1.name == "john")), :salary], fn prev ->
      ...>   {prev, 15}
      ...> end)
      {10, [%{name: "john", salary: 15}, %{name: "francine", salary: 30}]}

  `find/1` can also be used to pop elements out of a list or
  a key inside of a list:

      iex> list = [%{name: "john", salary: 10}, %{name: "francine", salary: 30}]
      iex> pop_in(list, [Kubereq.Kubeconfig.Access.find!(&(&1.name == "francine"))])
      {%{name: "francine", salary: 30}, [%{name: "john", salary: 10}]}
      iex> pop_in(list, [Kubereq.Kubeconfig.Access.find!(&(&1.name == "francine")), :name])
      {"francine", [%{salary: 30}, %{name: "john", salary: 10}]}
      iex> get_in(list, [Kubereq.Kubeconfig.Access.find!(&(&1.name == "adam")), :salary])
      ** (ArgumentError) There is no item in the list for which the given function returns a truthy value.

  When multiple items exist for which `fun` return a truthy value, the first one is accessed.

      iex> list = [%{name: "john", salary: 10}, %{name: "john", salary: 30}]
      iex> get_in(list, [Kubereq.Kubeconfig.Access.find!(&(&1.name == "john")), :salary])
      10

  An error is raised if the accessed structure is not a list:

      iex> get_in(%{}, [Kubereq.Kubeconfig.Access.find!(&(&1.name == "john"))])
      ** (RuntimeError) Kubereq.Kubeconfig.Access.find!/1 expected a list, got: %{}
  """
  @spec find!((term -> boolean)) :: Access.access_fun(data :: list, current_value :: list)
  def find!(func) when is_function(func) do
    fn op, data, next -> find!(op, data, func, next) end
  end

  defp find!(:get, data, func, next) when is_list(data) do
    case Enum.find(data, func) do
      nil ->
        raise ArgumentError,
              "There is no item in the list for which the given function returns a truthy value."

      item ->
        next.(item)
    end
  end

  defp find!(:get_and_update, data, func, next) when is_list(data) do
    get_and_update_find(data, func, next)
  end

  defp find!(_op, data, _func, _next) do
    raise "Kubereq.Kubeconfig.Access.find!/1 expected a list, got: #{inspect(data)}"
  end

  defp get_and_update_find(data, func, next, default \\ nil, raise? \\ true) do
    {value, rest} =
      case Enum.find_index(data, func) do
        nil when raise? ->
          raise ArgumentError,
                "There is no item in the list for which the given function returns a truthy value."

        nil ->
          {default, data}

        index ->
          List.pop_at(data, index)
      end

    case next.(value) do
      {get, update} -> {get, [update | rest]}
      :pop -> {value, rest}
    end
  end
end
