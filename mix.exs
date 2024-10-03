defmodule Kubereq.MixProject do
  use Mix.Project

  @app :kubereq
  @source_url "https://github.com/mruoss/#{@app}"
  @version "0.2.1"

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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.0"},
      {:pluggable, "~> 1.0"},
      {:req, "~> 0.5.0"},
      {:yaml_elixir, "~> 2.0"},

      # Test deps
      {:excoveralls, "~> 0.18", only: :test},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.0", only: :test},

      # Dev deps
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md"
      ]
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
      files: ["lib", "mix.exs", "README.md", "LICENSE.md", "CHANGELOG.md", ".formatter.exs"]
    ]
  end

  defp dialyzer do
    [
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/#{@app}.plt"}
    ]
  end
end
