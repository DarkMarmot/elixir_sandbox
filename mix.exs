defmodule Sandbox.MixProject do
  use Mix.Project

  def project do
    [
      app: :sandbox,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Sandbox",
      source_url: "https://github.com/darkmarmot/elixir_sandbox",
      homepage_url: "https://github.com/darkmarmot/elixir_sandbox",
      docs: [
        # The main page in the docs
        main: "Sandbox",
        #        logo: "path/to/logo.png",
        extras: ["README.md"]
      ],
      author: "Scott Southworth"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
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
