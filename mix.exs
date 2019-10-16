defmodule MixDeploy.MixProject do
  use Mix.Project

  def project do
    [
      app: :mix_deploy,
      version: "0.5.0",
      elixir: "~> 1.6",
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
      {:ex_doc, "~> 0.19.2", only: :dev, runtime: false},
      {:mix_systemd, git: "https://github.com/cogini/mix_systemd.git"},
      # {:mix_systemd, "~> 0.1.0"}
      # {:dialyxir, "~> 0.5.1", only: [:dev, :test], runtime: false},
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
