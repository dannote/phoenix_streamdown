defmodule PhoenixStreamdown.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/dannote/phoenix_streamdown"

  def project do
    [
      app: :phoenix_streamdown,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "PhoenixStreamdown",
      description: "Streaming markdown renderer for Phoenix LiveView, optimized for LLM output",
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:mdex, "~> 0.11"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "PhoenixStreamdown",
      source_ref: "v#{@version}"
    ]
  end
end
