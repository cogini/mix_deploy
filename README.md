# mix_deploy

This module generates scripts which help deploy an Erlang release created with
Elixir 1.9's [native release support](https://hexdocs.pm/mix/Mix.Tasks.Release.html)
or [Distillery](https://hexdocs.pm/distillery/home.html).

It supports deployment to the local machine, bare-metal servers
or cloud servers using e.g. [AWS CodeDeploy](https://aws.amazon.com/codedeploy/).

It generates scripts which can be run on the local machine or copied to a
target machine to handle lifecycle tasks such as creating initial directory
structure, unpacking release files, managing configuration, and starting/stopping,

It uses the [mix_systemd](https://github.com/cogini/mix_systemd)
library to generate a systemd unit file for the application, and shares
conventions with it about naming files and systemd unit files.

Here is [a complete example app which uses mix_deploy](https://github.com/cogini/mix-deploy-example).

## Installation

Add `mix_deploy` to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mix_deploy, "~> 0.7.0"},
  ]
end
```

## Configuration

The library gets standard information from `mix.exs`, e.g. the app name and
version, then calculates default values for its configuration parameters.

The library tries to choose smart defaults, so you may not need to configure
anything.

By default, with no configuration, the scripts are set up for building and
deploying on the same machine. You can log into a server, check out your code,
build a release, then deploy it supervised using systemd. The scripts create
a directory structure under e.g. `/srv/foo` and copy the release there. The
files are owned by the same OS user that runs the `mix deploy.generate` command.
It runs the app under an OS user with the same name as the app, e.g. `foo`.

You can override these parameters using settings in `config/config.exs`.
If you are deploying to a remote server as the `deploy` user and running
the app under the `app` user, the config would be:

```elixir
config :mix_systemd,
  app_user: "app",
  app_group: "app"

config :mix_deploy,
  deploy_user: "deploy",
  deploy_group: "deploy",
  app_user: "app",
  app_group: "app"
```

See below for more options.

## Usage

The `deploy.init` task copies template files from the library into your
project, then the `deploy.generate` task uses them to create the output files.

First, initialize templates under the `rel/templates/deploy` directory by
running:

```shell
mix deploy.init
```

Next, generate the scripts based on your project's config:

```shell
MIX_ENV=prod mix deploy.generate
chmod +x bin/*
```

By default, `mix deploy.generate` creates scripts under a `bin` directory at
the top level of your project. If you want to keep them separate, e.g. to
create different files based on the environment, set `output_dir_per_env: true`
in the config, and it will generate files under e.g. `_build/prod/deploy`.

## Scripts

The library generates the following scripts:

### Systemd scripts

These are simple wrappers on `systemctl`. They are useful for e.g. CodeDeploy
hook scripts where we have to run a script without parameters.

* `deploy-start`: Start services
* `deploy-stop`: Stop services
* `deploy-restart`: Restart services
* `deploy-enable`: Enable systemd units

### Local deploy scripts

* `deploy-create-users`: Create OS accounts for app and deploy users
* `deploy-create-dirs`: Create dirs, including the release dir `/srv/foo` and
                        standard dirs like `/etc/foo` or `/var/log/foo` if needed.
* `deploy-copy-files`: Copy files to target or staging directory, useful for local install or packaging
* `deploy-release`: Deploy release, extracting to a timestamped dir under `releases`, then making a symlink
* `deploy-rollback`: Rollback release, resetting the symlink to point to the last release

### CodeDeploy deploy scripts

* `deploy-create-users`: Create OS accounts for app and deploy users
* `deploy-create-dirs`: Create dirs, including the release dir `/srv/foo` and
                        standard dirs like `/etc/foo` or `/var/log/foo` if needed.
* `deploy-clean-target`: Delete files under target dir in preparation for deploying update
* `deploy-extract-release`: Extract release from tar
* `deploy-set-perms`: Set target file permissions so they can be used by deploy and/or app user

### Build server scripts

* `deploy-stage-files`: Copy output files to staging directory
* `deploy-sync-assets-s3`: Sync `priv/static` files to S3 bucket for CloudFront CDN

### Custom command scripts

These scripts set up the environment and then run release commands.
They run under the app user account, not under sudo. They are mainly useful
with Distillery, they are not needed now that Eixir 1.9+ mix releases have `rel/env.sh.eex`.

* `set-env`: Just set up environment
* `deploy-migrate`: Migrate database on target system by
  [running a custom command](https://www.cogini.com/blog/running-ecto-migrations-in-a-release/).
* `deploy-remote-console`: Launch a remote console for the app, setting up the environment properly.

### Environment setup scripts

These may be called by the systemd startup unit to get the config at runtime
based on the environment prior to starting up the app. Now that Eixir 1.9+ mix releases
have `rel/env.sh.eex`, these functions are better done there.

* `deploy-sync-config-s3`: Sync config files from S3 bucket to app config dir
* `deploy-runtime-environment-file`: Create `#{runtime_dir}/environment`
  file on target from `cloud-init` metadata.
* `deploy-runtime-environment-wrap`: Get runtime environment from
  `cloud-init` [metadata](https://cloudinit.readthedocs.io/en/latest/topics/instancedata.html),
  set environment vars, then launch main script.
* `deploy-set-cookie-ssm`: Get Erlang VM cookie from [AWS SSM Parameter
  Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-paramstore.html)
  and write to file.

### Dependencies

The generated scripts are mostly straight bash, with minimal dependencies.

* `deploy-runtime-environment-file` and `deploy-runtime-environment-wrap` use
[jq](https://stedolan.github.io/jq/) to parse the [cloud-init](https://cloud-init.io/) JSON file.
* `deploy-sync-config-s3` uses the [AWS CLI](https://aws.amazon.com/cli/) to copy files from an S3 bucket.
* `deploy-set-cookie-ssm` uses the AWS CLI and `jq` to interact with Systems Manager Parameter Store.

To install `jq` on Ubuntu:

```shell
apt-get install jq
```

To install the AWS CLI from the OS package manager on Ubuntu:

```shell
apt-get install awscli
```

## Scenarios

### Deploy on local machine

With a local deploy, you check out the code on a server, build/test, then
generate a release. You then run the scripts to set up the runtime environment,
including systemd unit scripts, extract the release to the target dir and run
it under systemd.

`deploy-init-local` is a convenience script which runs the other scripts to set
up the system:

```shell
sudo bin/deploy-init-local
```

It does the following:

```shell
# Create users to run the app
sudo bin/deploy-create-users

# Create deploy dirs under /srv/foo and app dirs like /etc/foo
sudo bin/deploy-create-dirs

# Copy scripts used at runtime by the systemd unit
sudo cp bin/* /srv/foo/bin

# Copy and enable systemd unit files
sudo bin/deploy-copy-files
sudo bin/deploy-enable
```

After the initial setup, build a release as you normally would:

```shell
# Create release
MIX_ENV=prod mix release
```

Then deploy the release to the local machine:

```shell
# Extract release to target directory, creating current symlink
bin/deploy-release

# Restart the systemd unit
sudo bin/deploy-restart
```

Roll back the release with the following:

```shell
bin/deploy-rollback
sudo bin/deploy-restart
```

This library generates the scripts with paths and users based on the
application configuration.

By default, the scripts deploy the scripts as the same OS user that runs the
`mix deploy.generate` command, and run the app under an OS user with the same
name as the app.

You can override some variables using environment vars at execution time.  For
example, you can override the user accounts which own the files by setting the
environment vars `APP_USER`, `APP_GROUP`, and `DEPLOY_USER`.
Similarly, set `DESTDIR` and the copy script will add a prefix when copying
files. This lets you copy files to a staging directory, tar it up, then extract
it on a target machine.

For example:

```shell
mkdir -p ~/tmp/deploy
DESTDIR=~/tmp/deploy bin/deploy-create-dirs
DESTDIR=~/tmp/deploy bin/deploy-copy-files
```

### CodeDeploy

Copy the scripts into the target machine, then run them as hooks for a
deployment system such as [AWS CodeDeploy](https://aws.amazon.com/codedeploy/).

Here is an example `appspec.yml` file:

```yaml
version: 0.0
os: linux
files:
  - source: bin
    destination: /srv/mix-deploy-example/bin
  - source: systemd
    destination: /lib/systemd/system
  - source: etc
    destination: /srv/mix-deploy-example/etc
hooks:
  ApplicationStop:
    - location: bin/deploy-stop
      timeout: 300
  BeforeInstall:
    - location: bin/deploy-create-users
    - location: bin/deploy-create-dirs
    - location: bin/deploy-clean-target
  AfterInstall:
    - location: bin/deploy-extract-release
    - location: bin/deploy-set-perms
    - location: bin/deploy-enable
  ApplicationStart:
    - location: bin/deploy-migrate
      runas: app
      timeout: 300
    - location: bin/deploy-start
      timeout: 3600
  ValidateService:
    - location: bin/validate-service
      timeout: 3600
```

## Configuration options

The following sections describe common configuration options.
See `lib/mix/tasks/deploy.ex` for the details of more obscure options.

If you need to make changes not supported by the config options (contributions
welcome!), then you can check the templates into source control from
`rel/templates/deploy` and make your own changes. You can also check in the
generated scripts in the `bin` dir.

The list of templates to generate is in the `templates` config var.
You can modify this list to remove scripts, and they won't be generated.
You can also add your own scripts and they will be run as templates with the
config vars defined.

```elixir
templates: [
    "deploy-clean-target",
    "deploy-copy-files",
    "deploy-create-dirs",
    "deploy-create-users",
    "deploy-enable",
    "deploy-extract-release",
    "deploy-init-local",
    "deploy-migrate",
    "deploy-runtime-environment-file",
    "deploy-runtime-environment-wrap",
    "deploy-release",
    "deploy-remote-console",
    "deploy-restart",
    "deploy-rollback",
    "deploy-set-cookie-ssm",
    "deploy-set-perms",
    "deploy-start",
    "deploy-stop",
    "deploy-sync-config-s3",
]
```

### Basics

`app_name`: Elixir application name, an atom, `app` from project `mix.exs`.

`version`: `version` from `mix.exs` project.

`ext_name`: External name, used for files and directories.
Default `app_name` with underscores converted to "-".

`service_name`: Name of the systemd service. Default `ext_name`.

`base_dir`: Base directory where deploy files will go, default `/srv` to
follow systemd conventions.

`deploy_dir`: Directory where files will go, default `#{base_dir}/#{ext_name}`

`release_system`: `:mix | :distillery`, default `:mix`

Identifies the system which was used to generate the releases,
[Mix](https://hexdocs.pm/mix/Mix.Tasks.Release.html) or
[Distillery](https://hexdocs.pm/distillery/home.html).

### Users

`app_user`: OS user account that the app should run under. Default `ext_name`.

`app_group`: OS group account, default `ext_name`.

`deploy_user`: OS user account that is used to deploy the app, e.g. own the
files and restart it. For security, this is separate from `app_user`, keeping
the runtime user from being able to modify the source files. Defaults to the
user running the script, supporting local deploy. For remote deploy, set this
to a user like `deploy` or same as the app user.

`deploy_group`: OS group account, default `deploy_user`.

### Restarting

`restart_method`: `:systemctl | :systemd_flag | :touch`, default `:systemctl`

The normal situation is that the app will be restarted using `systemctl`, e.g.
`systemctl restart #{service_name}`.

With `:systemd_flag`, an additional systemd unit file watches for
changes to a flag file and restarts the main unit. This allows updates to be
pushed to the target machine by an unprivileged user account which does not
have permissions to restart processes. Touch the file `#{flags_dir}/restart.flag`
and systemd will restart the unit.  See `mix_systemd` for details.

With `:touch`, the app itself watches the file `#{flags_dir}/restart.flag`.
If it channges, the app shuts iself down, relying on systemd to notice and restart it.

`sudo_deploy`: Creates `/etc/sudoers.d/#{ext_name}` file wich allows the deploy
user to start/stop/restart the app using sudo. Default `false`. Note that
systemctl must be specified with the full path, e.g. `sudo /bin/systemctl restart foo`.

`sudo_app`: Creates `/etc/sudoers.d/#{ext_name}` file allowing the app user
user to start/stop/restart the app using sudo. Default `false`.

### Environment vars

The library sets a few common env vars:

* `mix_env`: default `Mix.env()`, sets `MIX_ENV`.
* `env_lang`: default `C.UTF-8`, used to set `LANG`.

### Directories

Modern Linux defines a set of directories which apps use for common
purposes, e.g. configuration or cache files. App files are under `/srv`,
configuration under `/etc`, transient files under `/run`, data under
`/var/lib`. See
[systemd.exec](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#RuntimeDirectory=)
for details.

Directories are named based on the app name, e.g. `/etc/#{ext_name}`.
The `dirs` variable specifies which directories the app uses, by default:

```elixir
dirs: [
  :runtime,       # App runtime files which may be deleted between runs, /run/#{ext_name}
                  # Used for RELEASE_TMP, RELEASE_MUTABLE_DIR, runtime environment
  :configuration, # App configuration, e.g. db passwords, /etc/#{ext_name}
  # :state,       # App data or state persisted between runs, /var/lib/#{ext_name}
  # :cache,       # App cache files which can be deleted, /var/cache/#{ext_name}
  # :logs,        # App external log files, not via journald, /var/log/#{ext_name}
  # :tmp,         # App temp files, /var/tmp/#{ext_name}
],
```

More recent versions of systemd (after 235) will create these directories at
start time based on the settings in the unit file. For earlier systemd
versions, `deploy-create-dirs` will create them.

For security, we set permissions to 750, more restrictive than the
systemd defaults of 755. You can configure them with variables like
`configuration_directory_mode`. See the defaults in `lib/mix/tasks/deploy.ex`.

`systemd_version`: Sets the systemd version on the target system, default 235.
This determines which systemd features the library will enable. If you are
targeting an older OS release, you may need to change it. Here are the systemd
versions in common OS releases:

* CentOS 7: 219
* Ubuntu 16.04: 229
* Ubuntu 18.04: 237

### Additional directories

The library uses a directory structure under `deploy_dir` which allows it to
handle multiple releases, similar to
[Capistrano](https://capistranorb.com/documentation/getting-started/structure/).

* `scripts_dir`:  deployment scripts which e.g. start and stop the unit, default `bin`.
* `current_dir`: where the current Erlang release is unpacked or referenced by symlink, default `current`.
* `releases_dir`: where versioned releases are unpacked, default `releases`.
* `flags_dir`: dir for flag files to trigger restart, e.g. when `restart_method` is `:systemd_flag`, default `flags`.

When using multiple releases and symlinks, the deployment process works like this:

1. Create a new directory for the release with a timestamp like
   `/srv/foo/releases/20181114T072116`.

2. Upload the new release tarball to the server and unpack it to the releases dir

3. Make a symlink from `/srv/#{ext_name}/current` to the new release dir.

4. Restart the app.

If you are only keeping a single version, then deploy it to the
`/srv/#{ext_name}/current` dir.

### Configuration

Configuration of an Elixir app can be split into three parts:

**Build time** settings are consistent for all servers, though they may have
different options between e.g. staging and production. This is handled by
config files `config/config.exs` and `config/prod.exs`, which result in an
initial fixed application environment file in the release.

**Environment / per machine / secrets** settings depend on the environment the
application is running in, e.g. the hostname of the db server and secrets like
the db password. We store these external to the application release file and load
them from files or a configuration system like AWS Systems Manager Parameter
Store or etcd.

Elixir 1.9+ releases can execute an Elixir file (`config/releases.exs`)
every time the release boots. You can also use [config
providers](https://hexdocs.pm/elixir/Config.Provider.html) to load files in
standard formats like [TOML](https://hexdocs.pm/toml_config/readme.html).
They can also run the shell file generated by the template `rel/env.sh.eex`
to set up the environment.

This library generates scripts which can be called by systemd to get configuration.
See [mix_systemd](https://github.com/cogini/mix_systemd) for details.

`deploy-sync-config-s3` syncs config files from an S3 bucket to the
app config dir, e.g. `/etc/foo`. For example, we can use a config file in
[TOML](https://github.com/toml-lang/toml) format read at startup by the
[TOML configuration provider](https://github.com/bitwalker/toml-elixir).

[Conform](https://github.com/bitwalker/conform) is a similar way of making a
machine-specific config file. Conform has been depreciated in favor of
[TOML](https://github.com/bitwalker/toml-elixir).

`deploy-set-cookie-ssm` gets the Erlang VM cookie from [AWS SSM
Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-paramstore.html)
and writes it to a file.

**Dynamic** settings may change every time the application starts.  For
example, the IP address of the server may change if it is rebooted.

`deploy-runtime-environment-file` reads config from `cloud-init` and
writes it to an environment file `#{runtime_dir}/environment`.

Similarly, `deploy-runtime-environment-wrap` gets `cloud-init` metadata, sets
environment vars, then launches the main start script. This is probably best done
by `rel/env.sh.eex` now.

If these are not flexible enough, you can make your own systemd unit which
is set as a dependency of the app unit, so it will run first. Set
`runtime_environment_service` to `true` here and configure it in `mix_systemd`.

# Syncing config from S3

Here is a complete example of configuring an app from a config file which
it pulls from S3 on startup.

We set up an `ExecStartPre` command in the systemd unit file which runs
`deploy-sync-config-s3` before starting the app. It runs the AWS cli command:

```shell
aws s3 sync "s3://${CONFIG_S3_BUCKET}/${CONFIG_S3_PREFIX}" "${CONFIG_DIR}/"
```

`CONFIG_S3_BUCKET` is the source bucket, and `CONFIG_S3_PREFIX` is an optional
path in the bucket. `CONFIG_DIR` is the app configuration dir on the target
system, `/etc/foo`.

Set `exec_start_pre` in the `mix_systemd` config:

```elixir
config :mix_systemd,
  app_user: "foo",
  app_group: "foo",
  exec_start_pre: [
    "!/srv/foo/bin/deploy-sync-config-s3"
  ]
```

For security, the app only has read-only access to its config files, and
`/etc/foo` has ownership `deploy:foo` and mode 750. We prefix the command
with "!" so it runs with elevated permissions, not as the `foo` user.

We need to set the `CONFIG_S3_BUCKET` variable in the environment so that
`deploy-sync-config-s3` can use it.

The systemd unit has `EnvironmentFile` commands which load environment
variables from a series of files.

    EnvironmentFile=-/srv/foo/current/etc/environment
    EnvironmentFile=-/srv/foo/etc/environment
    EnvironmentFile=-/etc/foo/environment
    EnvironmentFile=-/run/foo/environment

The systemd unit tries to load each in turn, and later files override earlier ones.
The "-" on the front makes the file optional.

* `/srv/foo/current/etc/environment` settings are part of the release, and are
configured at build time in the CI system.

* `/srv/foo/etc/environment` settings are configured at deploy time.

* `/etc/foo/environment` settings might come from an S3
bucket.

* `/run/foo/environment` settings are generated dynamically.

For example, `post_build` commands in the CodeBuild CI `buildspec.yml` file
can generate a config file `files/etc/environment`:

```yaml
post_build:
  commands:
    - mkdir -p files/etc
    - echo "CONFIG_S3_BUCKET=$BUCKET_CONFIG" >> files/etc/environment
```

Then the CodeDeploy `appspec.yml` copies it to the target system under `/srv/foo/etc`:

```yaml
files:
  - source: bin
    destination: /srv/foo/bin
  - source: systemd
    destination: /lib/systemd/system
  - source: etc
    destination: /srv/foo/etc
```
