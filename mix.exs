defmodule DogStatsd.Mixfile do
  use Mix.Project

  def project do
    [app: :dogstatsd,
     version: version(),
     elixir: "~> 1.0",
     test_coverage: [tool: ExCoveralls],
     deps: deps(),
     package: package(),
     description: "A client for DogStatsd, an extension of the StatsD metric server for Datadog."
     ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:credo, "~> 1.0.0", [only: [:dev, :test], runtime: false]},
      {:excoveralls, "~> 0.6.3", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp package do
    [
       name: :dogstatsd,
       files: ["lib/*", "mix.exs", "README.md", "LICENSE.md", "CHANGELOG.md", "VERSION.yml"],
       maintainers: ["Adam Kittelson"],
       licenses: ["MIT"],
       links: %{ "GitHub" => "https://github.com/adamkittelson/dogstatsd-elixir" }
     ]
  end

  defp version do
     ~r/[0-9]+/
     |> Regex.scan(File.read!("VERSION.yml"))
     |> List.flatten
     |> Enum.join(".")
  end
end
