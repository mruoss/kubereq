defmodule Kubereq do
  alias Kubereq.Step

  defmacro __using__(_opts) do
    quote do
      use Pluggable.StepBuilder

      def req(opts \\ []) do
        %Kubeconf{}
        |> Pluggable.run([{__MODULE__, nil}])
        |> Kubereq.req(opts)
      end
    end
  end

  @spec req(Kubeconf.t(), keyword()) :: Req.Request.t()
  def req(kubeconfig, opts) do
    Req.new()
    |> Req.Request.register_options([:kubeconfig])
    |> Step.Exec.attach()
    |> Step.FieldSelector.attach()
    |> Step.LabelSelector.attach()
    |> Step.Compression.attach()
    |> Step.TLS.attach()
    |> Step.Auth.attach()
    |> Step.Impersonate.attach()
    |> Step.BaseUrl.attach()
    |> Req.merge(opts)
    |> Req.merge(kubeconfig: kubeconfig)

    # |> Req.Request.append_request_steps(debug: &dbg/1)
  end
end
