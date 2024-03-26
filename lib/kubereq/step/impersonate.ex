defmodule Kubereq.Step.Impersonate do
  @moduledoc """
  Req step to derive impersonation headers from the Kubeconfig.
  """

  alias Kubereq.Error.StepError

  @spec attach(Req.Request.t()) :: Req.Request.t()
  def attach(req) do
    Req.Request.prepend_request_steps(req, kubereq_impersonate: &call/1)
  end

  @spec call(req :: Req.Request.t()) :: Req.Request.t()
  def call(req) when not is_map_key(req.options, :kubeconfig) do
    raise StepError.new(:kubeconfig_not_loaded)
  end

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
