defmodule PhoenixStreamdown.MixProject do
  use Mix.Project

  @version "1.0.0-beta.3"
  @source_url "https://github.com/dannote/phoenix_streamdown"

  def project do
    [
      app: :phoenix_streamdown,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      name: "PhoenixStreamdown",
      description: "Streaming markdown renderer for Phoenix LiveView, optimized for LLM output",
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url,
      dialyzer: [
        plt_add_apps: [:ex_unit],
        plt_file: {:no_warn, "priv/plts/project.plt"}
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [preferred_envs: [ci: :test]]
  end

  defp aliases do
    [
      ci: [
        "compile --warnings-as-errors",
        "test",
        "credo --strict",
        "dialyzer"
      ]
    ]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:mdex, "~> 0.11"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url, "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"},
      files: ~w(lib priv/static .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "PhoenixStreamdown",
      source_ref: "v#{@version}",
      extras: ["CHANGELOG.md"]
    ]
  end
end
