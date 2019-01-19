# mix_deploy_local

This module provides mix tasks which deploy a
[Distillery](https://github.com/bitwalker/distillery) release to the local machine.

It uses a structure similar to [Capistrano](https://capistranorb.com/documentation/getting-started/structure/).

It creates a base directory, by default `/srv/:app`, where `:app` is
the name of the application with underscores replaced by dashes.

Under that, the `releases` directory holds the files from the release
in a directory named with the current timestamp, e.g. `/srv/example-app/releases/20180628115441`.
It makes a symlink from the release tirectory to `/srv/example-app/current`.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `mix_deploy_local` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:distillery, "~> 2.0"},
    {:mix_deploy_local, "~> 0.1.0"}
  ]
end
```

## Configuration

This module looks for configuration in the
mix project under the `mix_deploy_local` key.

`base_path` sets the base directory, default `/srv`.

`deploy_path` sets the target directory completely manually, ignoring `base_path` and `app`.

```elixir
def project do
[
  app: :example_app,
  version: "0.1.0",
  elixir: "~> 1.6",
  start_permanent: Mix.env() == :prod,
  deps: deps(),
  mix_deploy_local: [
    deploy_path: "/my/special/place/myapp"
  ]
]
end
```

## Usage

```shell
# Create directory under /srv
sudo mix deploy.local.init

# Deploy current release tar from distillery to
# /srv/example-app/releases/20180628115441 and
# update symlink from /srv/example-app/current
mix deploy.local

# Deploy specific release version
mix deploy.local --version=0.2.0

# Update symlink to point to previous release
mix deploy.local.rollback
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/mix_deploy_local](https://hexdocs.pm/mix_deploy_local).
