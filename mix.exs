defmodule MixDeploy.MixProject do
  use Mix.Project

  @github "https://github.com/cogini/mix_deploy"
  @version "0.8.0"

  def project do
    [
      app: :mix_deploy,
      version: @version,
      elixir: "~> 1.12",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      dialyzer: [
        plt_add_apps: [:mix, :eex]
        # plt_add_deps: true,
        # flags: ["-Werror_handling", "-Wrace_conditions"],
        # flags: ["-Wunmatched_returns", :error_handling, :race_conditions, :underspecs],
        # ignore_warnings: "dialyzer.ignore-warnings"
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.lcov": :test,
        quality: :test,
        "quality.ci": :test
      ],
      description: description(),
      package: package(),
      source_url: @github,
      homepage_url: @github,
      docs: docs(),
      deps: deps(),
      releases: releases()
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

  def application do
    [
      extra_applications: [:logger, :eex]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.33.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18.0", only: [:dev, :test], runtime: false},
      {:junit_formatter, "~> 3.3", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},
      {:mix_systemd, "~> 0.8"},
      {:styler, "~> 0.11.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "Generate deployment scripts for an application."
  end

  defp package do
    [
      description: description(),
      maintainers: ["Jake Morrison"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github,
        "Changelog" =>
          "#{@github}/blob/#{@version}/CHANGELOG.md##{String.replace(@version, ".", "")}"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @github,
      source_ref: @version,
      extras: [
        "README.md",
        "CHANGELOG.md": [title: "Changelog"],
        "LICENSE.md": [title: "License (Apache-2.0)"],
        "CONTRIBUTING.md": [title: "Contributing"],
        "CODE_OF_CONDUCT.md": [title: "Code of Conduct"]
      ],
      # api_reference: false,
      source_url_pattern: "#{@github}/blob/master/%{path}#L%{line}"
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      quality: [
        "test",
        "format --check-formatted",
        # "credo",
        "credo --mute-exit-status",
        # mix deps.clean --unlock --unused
        "deps.unlock --check-unused",
        # mix deps.update
        # "hex.outdated",
        # "hex.audit",
        "deps.audit",
        "dialyzer --quiet-with-result"
      ],
      "quality.ci": [
        "format --check-formatted",
        "deps.unlock --check-unused",
        # "hex.outdated",
        "hex.audit",
        "deps.audit",
        "credo",
        "dialyzer --quiet-with-result"
      ]
    ]
  end
end
