defmodule MixDeploy.MixProject do
  use Mix.Project

  def project do
    [
      app: :mix_deploy,
      version: "0.1.7",
      elixir: "~> 1.9",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: "https://github.com/cogini/mix_deploy",
      homepage_url: "https://github.com/cogini/mix_deploy",
      dialyzer: [
        plt_add_apps: [:mix, :eex]
        # plt_add_deps: true,
        # flags: ["-Werror_handling", "-Wrace_conditions"],
        # flags: ["-Wunmatched_returns", :error_handling, :race_conditions, :underspecs],
        # ignore_warnings: "dialyzer.ignore-warnings"
      ],
      deps: deps(),
      docs: docs()
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
      {:mix_systemd, "~> 0.7.0", organization: "narrativeapp"},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test]},
      {:credo, "~> 1.5.1", only: [:dev, :test], runtime: false}

      # {:mix_systemd, "~> 0.1.0"}
      # {:dialyxir, "~> 0.5.1", only: [:dev, :test], runtime: false},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end

  defp description do
    "Generates deployment scripts for an application."
  end

  defp package do
    [
      maintainers: ["Jake Morrison"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/cogini/mix_deploy"}
    ]
  end

  defp docs do
    [
      source_url: "https://github.com/cogini/mix_deploy",
      extras: ["README.md"]
    ]
  end
end
