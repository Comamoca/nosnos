defmodule Nosnos.MixProject do
  use Mix.Project

  def project do
    [
      app: :nosnos,
      version: "0.2.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: "https://github.com/Comamoca/nosnos"
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
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:zigler, "~> 0.15.1", runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description do
    "High-performance Nostr cryptographic operations library implementing BIP-340 Schnorr signatures using Zig NIFs"
  end

  defp package do
    [
      name: "nosnos",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Comamoca/nosnos"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE.md)
    ]
  end
end
