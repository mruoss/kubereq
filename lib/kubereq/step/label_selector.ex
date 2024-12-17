defmodule Kubereq.Step.LabelSelector do
  @moduledoc """
  Req step to format label selectors.

  Label selectors are used to filter list and watch operations by resource
  labels. The concept is explained on the Kubernetes
  documentation [Labels and Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels)

  The functions for listing and watching resources accept an option
  `:label_selectors` as a list of strings or tuples.

  ### Equality-based requirements

  The following are equivalent label selectors for equality:

  * `"environment = production"`
  * `{"environment", "production"}`
  * `{"environment", {:eq, "production"}}`

  The following are equivalent label selectors for inequality:

  * `"tier != frontend"`
  * `{"tier", {:neq, "frontend"}}`
  * `{"tier", {:ne, "frontend"}}`

  ### Set-based requirements

  The following are equivalent label selectors for `In` requirements:

  * `"environment in (production, qa)"`
  * `{"environment", ["production", "qa"]}`
  * `{"environment", {:in, ["production", "qa"]}}`

  The following are equivalent label selectors for `NotIn` requirements:

  * `"tier notin (frontend, backend)"`
  * `{"tier", {:notin, ["frontend", "backend"]}}`
  * `{"tier", {:not_in, ["frontend", "backend"]}}`

  The following are equivalent label selectors for `Exists` requirements:

  * `"partition"`
  * `{"partition"}`
  * `{"partition", :exists}`

  The following are equivalent label selectors for `not DoesNotExist` requirements:

  * `"!partition"`
  * `{"!partition"}`
  * `{"partition", :notexists}`
  * `{"partition", :not_exists}`

  """

  def call(%Req.Request{options: %{label_selectors: nil}} = req), do: req

  def call(%Req.Request{options: %{label_selectors: label_selectors}} = req) do
    label_selector =
      label_selectors
      |> to_list()
      |> Enum.map_join(",", &format/1)

    Req.merge(req, params: [labelSelector: label_selector])
  end

  def call(req), do: req

  defp to_list(label_selectors) when is_map(label_selectors), do: Enum.to_list(label_selectors)
  defp to_list(label_selectors), do: List.wrap(label_selectors)

  # preformatted label selector
  defp format(label_selector) when is_binary(label_selector), do: label_selector

  # equality-based requirements
  defp format({key, {:eq, value}}) when is_binary(value), do: "#{key}=#{value}"
  defp format({key, value}) when is_binary(value), do: format({key, {:eq, value}})

  # inequality-based requirements
  defp format({key, {neq, value}}) when is_binary(value) and neq in [:ne, :neq],
    do: "#{key}!=#{value}"

  # set-based requirements (In)
  defp format({key, {:in, values}}) when is_list(values),
    do: "#{key} in (#{Enum.join(values, ", ")})"

  defp format({key, values}) when is_list(values), do: format({key, {:in, values}})

  # set-based requirements (NotIn)
  defp format({key, {notin, values}}) when is_list(values) and notin in [:notin, :not_in],
    do: "#{key} notin (#{Enum.join(values, ", ")})"

  # set-based requirements (Exists/NotExists)
  defp format({key}) when is_binary(key), do: key
  defp format({key, :exists}) when is_binary(key), do: key
  defp format({key, :notexists}) when is_binary(key), do: "!#{key}"
  defp format({key, :not_exists}) when is_binary(key), do: "!#{key}"
end
