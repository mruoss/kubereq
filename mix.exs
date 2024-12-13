defmodule Kubereq.MixProject do
  use Mix.Project

  @app :kubereq
  @source_url "https://github.com/mruoss/#{@app}"
  @version "0.4.0"

  def project do
    [
      app: @app,
      description: "A Kubernetes Client using Req.",
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(Mix.env()),
      docs: docs(),
      preferred_cli_env: cli_env(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: dialyzer()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Kubereq.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["test/support" | elixirc_paths(:prod)]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps(:test) do
    # Until a new version with https://github.com/wojtekmach/req/issues/440 is
    # released
    [{:req, github: "wojtekmach/req", env: :test, only: :test} | deps(:all)]
  end

  defp deps(env) when env not in [:test, :all] do
    [{:req, "~> 0.5.0"} | deps(:all)]
  end

  defp deps(:all) do
    [
      {:jason, "~> 1.0"},
      {:pluggable, "~> 1.0"},
      {:yaml_elixir, "~> 2.0"},
      {:mint, "~> 1.0"},
      {:mint_web_socket, "~> 1.0"},
      {:fresh, "~> 0.4.4"},

      # Test deps
      {:excoveralls, "~> 0.18", only: :test},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.0", only: :test},

      # Dev deps
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "Kubereq",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md"
      ],
      groups_for_modules: [
        "Websocket Connection": [
          Kubereq.PodExec,
          Kubereq.PodLogs
        ],
        "Kubeconfig Loading": [
          Kubereq.Kubeconfig,
          Kubereq.Kubeconfig.Default,
          Kubereq.Kubeconfig.ENV,
          Kubereq.Kubeconfig.File,
          Kubereq.Kubeconfig.ServiceAccount,
          Kubereq.Kubeconfig.Stub
        ],
        Selectors: [
          Kubereq.Step.FieldSelector,
          Kubereq.Step.LabelSelector
        ]
      ],
      before_closing_head_tag: &before_closing_head_tag/1
    ]
  end

  defp cli_env do
    [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test,
      "coveralls.travis": :test,
      "coveralls.github": :test,
      "coveralls.xml": :test,
      "coveralls.json": :test
    ]
  end

  defp package do
    [
      name: @app,
      maintainers: ["Michael Ruoss"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "https://hexdocs.pm/#{@app}/changelog.html",
        "Sponsor" => "https://github.com/sponsors/mruoss"
      },
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "LICENSE.md",
        "CHANGELOG.md",
        ".formatter.exs"
      ]
    ]
  end

  defp dialyzer do
    [
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/#{@app}.plt"}
    ]
  end

  defp before_closing_head_tag(:html) do
    """
    <script>
      function mermaidLoaded() {
        mermaid.initialize({
          startOnLoad: false,
          theme: document.body.className.includes("dark") ? "dark" : "default"
        });
        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const preEl = codeEl.parentElement;
          const graphDefinition = codeEl.textContent;
          const graphEl = document.createElement("div");
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
            graphEl.innerHTML = svg;
            bindFunctions?.(graphEl);
            preEl.insertAdjacentElement("afterend", graphEl);
            preEl.remove();
          });
        }
      }
    </script>
    <script async src="https://cdn.jsdelivr.net/npm/mermaid@10.2.3/dist/mermaid.min.js" onload="mermaidLoaded();"></script>
    """
  end

  defp before_closing_head_tag(_), do: ""
end
