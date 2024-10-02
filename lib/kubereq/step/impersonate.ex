defmodule Kubereq.Step.Impersonate do
  @moduledoc false

  alias Kubereq.Error.StepError

  @spec call(req :: Req.Request.t()) :: Req.Request.t() | {Req.Request.t(), StepError.t()}
  def call(req) do
    impersonate(req, req.options.kubeconfig.current_user)
  end

  @spec impersonate(Req.Request.t(), map()) :: Req.Request.t()
  defp impersonate(req, user) do
    groups = for group <- List.wrap(user["as-groups"]), do: {"Impersonate-Group", group}

    extras =
      for {name, values} <- user["as-user-extra"] || %{}, value <- values do
        {"Impersonate-Extra-#{name}", value}
      end

    headers =
      [
        {"Impersonate-User", user["as"]},
        {"Impersonate-Uid", user["as-uid"]},
        groups,
        extras
      ]
      |> List.flatten()
      |> Enum.filter(&elem(&1, 1))

    Req.merge(req, headers: headers)
  end
end
