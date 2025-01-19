defmodule Kubereq.MixProject do
  use Mix.Project

  @app :kubereq
  @source_url "https://github.com/mruoss/#{@app}"
  @version "0.4.1"

  def project do
    [
      app: @app,
      description: "A Kubernetes Client using Req.",
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
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

  defp deps() do
    elixir_version = System.version() |> Version.parse!()

    [
      (elixir_version.major == 1 and elixir_version.minor) < 18 && {:jason, "~> 1.0"},
      {:pluggable, "~> 1.0"},
      {:yaml_elixir, "~> 2.0"},
      {:mint, "~> 1.0"},
      {:mint_web_socket, "~> 1.0"},
      {:req, "~> 0.5.0"},

      # Test deps
      {:excoveralls, "~> 0.18", only: :test},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.0", only: :test},

      # Dev deps
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.36", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4.0", only: [:dev, :test], runtime: false}
    ]
    |> Enum.filter(& &1)
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
