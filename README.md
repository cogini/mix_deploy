# mix_deploy

This module provides mix tasks which deploy a
[Distillery](https://github.com/bitwalker/distillery) release.

It supports deployment to the local machine, bare-metal servers
and deployment to cloud servers using e.g. [AWS CodeDeploy](https://aws.amazon.com/codedeploy/).

It works by generating a set of scripts under the project `bin` directory which
can be run on the local machine or copied to a target machine to handle
lifecyle tasks such as initial setup, unpacking release files, configuration,
and starting/stopping,

It uses the [mix_systemd](https://github.com/cogini/mix_systemd)
library to generate a systemd unit file for the application, and shares
conventions with it about naming files and systemd unit files.

## Installation

Add `mix_deploy` to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:distillery, "~> 2.0"},
    {:mix_deploy, "~> 0.1.0"}
  ]
end
```

## Usage

This library works similarly to [Distillery](https://hexdocs.pm/distillery/home.html).
The `init` task copies template files into your project, then the `generate`
task uses them to create the output files.

Run this command to initialize templates under the `rel/templates/deploy` directory:

```shell
MIX_ENV=prod deploy.init
```

Next, generate output files under your project's `bin` direcory:

```shell
MIX_ENV=prod mix deploy.generate
```

## Scripts

This library generates the following scripts:

* `deploy-start`: Start services on target
* `deploy-stop`: Stop services on target
* `deploy-restart`: Restart services on target
* `deploy-enable`: Enable systemd units on target
* `deploy-remote-console`: Launch a remote console on the app, setting up environment vars. It is run under the app user account.

* `deploy-create-users`: Create user accounts on target, e.g. `app_user`
* `deploy-create-dirs`: Create app dirs on target
* `deploy-clean-target`: Delete target dir files in preparation for install (CodeDeploy).
* `deploy-copy-files`: Copy files to target or staging directory
* `deploy-extract-release`: Extract release from tar to target dir (CodeDeploy)
* `deploy-set-perms`: Set file permissions

* `deploy-migrate`: Migrate database on target system. TODO: describe method

* `deploy-release`: Deploy release on local system, extracting to a timestamped releases dir, then making a symlink. (Local deploy)
* `deploy-rollback`: Rollback release on local system, resetting the symlink to point to the last release. (Local deploy)

* `deploy-runtime-environment-file`: Create `#{runtime_dir}/runtime-environment` file on target from `cloud-init` metadata
* `deploy-runtime-environment-wrap`: Get runtime environment from `cloud-init` metadata, set environment vars, then launch script
* `deploy-set-cookie-ssm`: Get Erlang VM cookie from AWS SSM Parameter Store and write to file
* `deploy-sync-config-s3`: Sync config files from S3 bucket to app config dir

## Scenarios

### Deploy on local machine

You can build your app and deploy on the local machine. First build the
Distillery release (`mix releasee`) then run:

```shell
# Create user to run the app
sudo bin/create-users

# Create directory structure under /srv
sudo bin/deploy-create-dirs

# Extract release to target directory, creating current symlink
bin/deploy-release

# Copy and enable systemd unit files
sudo bin/deploy-copy-files
sudo bin/deploy-enable
sudo bin/deploy-restart
```

You can roll back the release with the following:

```shell
bin/deploy-rollback
sudo bin/deploy-restart
```

The scripts support configuration using environment vars, e.g. you can set the
`DESTDIR` environment var and the copy script will add the `DESTDIR` prefix
when copying files. This lets you copy files to a staging directory, tar it up,
then extract it on a target machine.

For example:

```shell
mkdir -p ~/tmp/deploy
DESTDIR=~/tmp/deploy bin/deploy-create-dirs
DESTDIR=~/tmp/deploy bin/deploy-copy-files
```

### CodeDeploy

You can copy the scripts into the target machine, then run them as hooks for a deployment system
such as CodeDeploy.

Here is a typical `appspec.yml` file:

```yaml
version: 0.0
os: linux
files:
  - source: bin
    destination: /srv/foo/bin
  - source: systemd
    destination: /lib/systemd/system
hooks:
  ApplicationStop:
    - location: bin/deploy-stop
      timeout: 300
  BeforeInstall:
    - location: bin/deploy-create-users
    - location: bin/deploy-clean-target
  AfterInstall:
    - location: bin/deploy-extract-release
    - location: bin/deploy-set-perms
    - location: bin/deploy-enable
  ApplicationStart:
    # - location: bin/deploy-migrate
    #   runas: app
    #   timeout: 300
    - location: bin/deploy-start
      timeout: 3600
  ValidateService:
    - location: bin/validate-service
      timeout: 3600
```

## Configuration

The library gets standard information in `mix.exs`, e.g. the app name and
version, then calculates default values for its configuration parameters.

You can then override these parameters using settings in `config/config.exs`, e.g.:

```elixir
config :mix_systemd,
  app_user: "app",
  app_group: "app",
  runtime_environment_wrap: true,
  env_vars: [
    "REPLACE_OS_VARS=true",
  ],
  exec_start_pre: [
    "deploy-set-cookie-ssm"
  ]

config :mix_deploy,
  deploy_user: "deploy",
  deploy_group: "deploy",
  app_user: "app",
  app_group: "app"
```

The following sections describe configuration options.
See `lib/mix/tasks/deploy.ex` for the full details.

If you need to make changes not supported by the config options, then you can
check the templates into source control from `rel/templates/deploy` and make
your own changes (contributions welcome!). You can also check in the generated
scripts in the `bin` dir.

The list of templates to generate is in the `templates` config var.
You can modify this list to remove scripts, and they won't be generated.
You could also add your own scripts and they will be run as templates with the
config vars defined.

```elixir
templates: [
    "deploy-clean-target",
    "deploy-copy-files",
    "deploy-create-dirs",
    "deploy-create-users",
    "deploy-enable",
    "deploy-extract-release",
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

`app_name`: Elixir application name, an atom, from project `app` in `mix.exs`.

`version`: `version` from `mix.exs` project.

`ext_name`: External name, used for files and directories.
Defaults to `app_name` with underscores converted to "-".

`service_name`: Name of the systemd service. Defaults to `ext_name`.

`base_dir`: Base directory where deploy files will go, default is `/srv` to
follow systemd conventions.

`deploy_dir`: Directory where files will go, default is `#{base_dir}/#{ext_name}`

### Users

`app_user`: OS user account that the app should run under. Defaults to `ext_name`.

`app_group`: OS group account, defaults to `ext_name`.

`deploy_user`: OS user account that is used to deploy the app, e.g. own the
files and restart it.

For security, this is separate from `app_user`, keeping the runtime user from being
able to modify the source files.

This defaults to the user running the script, supporting local deploy.
For remote deploy, set this to a user like `deploy` or the same as the app user.

`deploy_group`: OS group account, defaults to `deploy_user`.

### Restarting

`restart_method`: `:systemctl | :systemd_flag | :touch`, default `:systemctl`

The normal situation is that the app will be restarted using `systemctl`, e.g.
`systemctl restart #{service_name}`.

`sudo_deploy`: Create an `/etc/sudoers.d/#{ext_name}` file allowing the deploy
user to start/stop/restart the the app using sudo. Default `false`.

`sudo_app`: Create an `/etc/sudoers.d/#{ext_name}` file allowing the app user
user to start/stop/restart the the app using sudo. Default `false`.

Set `restart_method` to `:systemd_flag`, and the library will generate an additional
unit file which watches for changes to a flag file and restarts the
main unit. This allows updates to be pushed to the target machine by an
unprivilieged user account which does not have permissions to restart
proccesses. `touch` the file `#{flags_dir}/restart.flag` and systemd will restart the unit.
See `mix_systemd` for details.


### Environment vars

The library sets a few common env vars:

* `mix_env`: default `Mix.env()`, sets `MIX_ENV`.
* `env_lang`: default `en_US.UTF-8`, used to set `LANG`.
* `conform`: default `false`. Sets `CONFORM_CONF_PATH` to `/etc/#{ext_name}/#{app_name}.conf` if true.

### Directories

Modern Linux defines a set of directories which apps use for common
purposes, e.g. configuration or cache files.
See https://www.freedesktop.org/software/systemd/man/systemd.exec.html#RuntimeDirectory=

This library defines these directories based on the app name, e.g. `/etc/#{ext_name}`.
It only creates directories that the app uses, default `runtime` (`/run/#{ext_name}`)
and `configuration` (`/etc/#{ext_name}`). If your app uses other dirs, set them in the
`dirs` var:

```elixir
dirs: [
  :runtime,       # Needed for RELEASE_MUTABLE_DIR, runtime-environment or conform
  :configuration, # Needed for Erlang cookie
  # :cache,       # App cache files which can be deleted
  # :logs,        # App external log files, not via journald
  # :state,       # App state persisted between runs
  # :tmp,         # App temp files
],
```

For security, we set permissions to 750, more restrictive than the
systemd defaults of 755. You can configure them with e.g. `configuration_directory_mode`.
See the defaults in `lib/mix/tasks/systemd.ex`.

More recent versions of systemd (after 235) will create these directories at start
time based on the settings in the unit file.

For earlier systemd versions, mix_deploy will create them.

`systemd_version`: Sets the systemd version on the target system, default 235.
This determines which systemd features the library will enable. If you are
targeting an older OS relese, you may need to change it. Here are the systemd
versions in common OS releases:

* CentOS 7: 219
* Ubuntu 16.04: 229
* Ubuntu 18.04: 237

### Additional directories

The library assues a directory structure under `deploy_dir` which allows it to handle multiple reases,
similar to [Capistrano](https://capistranorb.com/documentation/getting-started/structure/).

* `scripts_dir`:  dir for deployment scripts which e.g. start and stop the unit, default `bin`.
* `current_dir`: dir where the current Erlang release is unpacked or referenced by symlink, default `current`.
* `releases_dir`: dir where versioned releases may be unpacked, default `releases`.
* `flags_dir`: dir for flag files to trigger restart, e.g. when `restart_method` is `:systemd_flag`, default `flags`.

When using multiple releases and symlinks, the deployment process works like this:

1. Create a new directory for the release with a timestamp like
   `/srv/foo/releases/20181114T072116`.

2. Upload the new release tarball to the server and unpack it to the release dir

3. Make a symlink from `/srv/foo/current` to the new release dir.

4. Restart the app.

If you are only keeping a single version, then you would deploy it to
the `/srv/foo/current` dir.


### Runtime configuration

For configuration, we normally use a combination of build time settings, deploy
time settings, and runtime settings.  See
[mix_systemd](https://github.com/cogini/mix_systemd) for details.

[Conform](https://github.com/bitwalker/conform) is a popular way of making a
machine-specific config file. Set `conform` to `true`, and the library will
set `CONFORM_CONF_PATH` to `/etc/#{ext_name}/#{app_name}.conf`. Conform has been
depreciated in favor of [TOML](https://github.com/bitwalker/toml-elixir), so
you should use that instead. This is currently only used in the `deploy-remote-console`
script.

`runtime_environment_service`: Default `false`. Set to `true` if you are using a separate
`runtime-environment.service`.



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
