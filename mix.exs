defmodule MixDeploy.MixProject do
  use Mix.Project

  @version "0.1.7"

  def project do
    [
      app: :mix_deploy,
      version: @version,
      elixir: "~> 1.9",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: "https://github.com/cogini/mix_deploy",
      homepage_url: "https://github.com/cogini/mix_deploy",
      dialyzer: [
        plt_add_apps: [:mix, :eex]
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
      {:credo, "~> 1.5.1", only: ~w[dev test]a, runtime: false},
      {:ex_doc, ">= 0.0.0", only: ~w[dev test]a},
      {:git_ops, "~> 2.2", only: ~w[dev test]a, runtime: false},
      {:mix_systemd, "~> 0.7.0", organization: "narrativeapp"}
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
