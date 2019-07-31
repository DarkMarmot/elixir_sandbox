defmodule Sandbox.MixProject do
  use Mix.Project

  @version "0.1.0"
  def project do
    [
      app: :sandbox,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      name: "sandbox",
      source_url: "https://github.com/darkmarmot/elixir_sandbox",
      homepage_url: "https://github.com/darkmarmot/elixir_sandbox",
      docs: docs(),
      author: "Scott Southworth",
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package() do
    [
      name: "sandbox",
      maintainers: ["Scott Southworth"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/darkmarmot/elixir_sandbox"}
    ]
  end

  defp description() do
    """
    Sandbox provides restricted, isolated scripting environments for Elixir through the use of Lua by wrapping
    Robert Virding's Luerl library.
    """
  end

  defp docs() do
    [
      main: "Sandbox",
      name: "Sandbox",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/sandbox",
      source_url: "https://github.com/darkmarmot/elixir_sandbox",
      extras: []
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:luerl, "~> 0.4.0"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end
end
