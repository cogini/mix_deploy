defmodule MixDeploy.MixProject do
  use Mix.Project

  @github "https://github.com/cogini/mix_deploy"
  @version "0.7.9"

  def project do
    [
      app: :mix_deploy,
      version: @version,
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      source_url: @github,
      homepage_url: @github,
      docs: docs(),
      deps: deps(),
      releases: releases(),
      dialyzer: [
        plt_add_apps: [:mix, :eex],
        # plt_add_deps: true,
        # flags: ["-Werror_handling", "-Wrace_conditions"],
        flags: ["-Wunmatched_returns", :error_handling, :race_conditions, :underspecs],
        # ignore_warnings: "dialyzer.ignore-warnings"
      ]
    ]
  end

  defp releases do
    [
      mix_deploy: [
        include_executables_for: [:unix],
        steps: [:assemble, :tar]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :eex]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      # {:mix_systemd, git: "https://github.com/cogini/mix_systemd.git"},
      {:mix_systemd, "~> 0.7"},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
    ]
  end

  defp package do
    [
      description: "Generate deployment scripts for an application.",
      maintainers: ["Jake Morrison"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @github}
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md": [],
        "LICENSE": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @github,
      source_url_pattern: "#{@github}/blob/master/%{path}#L%{line}",
      formatters: ["html"]
    ]
  end
end
