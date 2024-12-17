defmodule Kubereq.Step.FieldSelector do
  @moduledoc """
  Req step to format field selectors.

  Field selectors let you select Kubernetes objects based on the value of one or more resource fields.
  The concept is explained on the Kubernetes documentation
  [Field Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/field-selectors/)

  The functions for listing and watching resources accept an option
  `:field_selectors` as a list of strings or tuples.

  ### Examples

  The following are equivalent field selectors for equality:

  * `"metadata.name=my-service"`
  * `"metadata.name==my-service"`
  * `{"metadata.name", "my-service"}
  * `{"metadata.name", {:eq, "my-service"}}

  The following are equivalent field selectors for inequality:

  * `"metadata.namespace!=default"`
  * `{"metadata.namespace", {:neq, "default"}}`
  * `{"metadata.namespace", {:ne, "default"}}`
  """

  def call(%Req.Request{options: %{field_selectors: nil}} = req), do: req

  def call(%Req.Request{options: %{field_selectors: field_selectors}} = req) do
    field_selector =
      field_selectors
      |> to_list()
      |> Enum.map_join(",", &format/1)

    Req.merge(req, params: [fieldSelector: field_selector])
  end

  def call(req), do: req

  defp to_list(field_selectors) when is_map(field_selectors), do: Enum.to_list(field_selectors)
  defp to_list(field_selectors), do: List.wrap(field_selectors)

  # preformatted field selector
  defp format(field_selector) when is_binary(field_selector), do: field_selector

  # equality-based requirements
  defp format({key, {:eq, value}}) when is_binary(value), do: "#{key}=#{value}"
  defp format({key, value}) when is_binary(value), do: format({key, {:eq, value}})

  # inequality-based requirements
  defp format({key, {neq, value}}) when is_binary(value) and neq in [:ne, :neq],
    do: "#{key}!=#{value}"
end
