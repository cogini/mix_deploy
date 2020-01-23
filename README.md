# mix_deploy

This module generates scripts which help deploy an Erlang release, handling
tasks such as creating initial directory structure, unpacking release files,
managing configuration, and starting/stopping.  It supports deployment to the
local machine, bare-metal servers or cloud servers using e.g.
[AWS CodeDeploy](https://aws.amazon.com/codedeploy/).

It supports releases created with Elixir 1.9+
[mix release](https://hexdocs.pm/mix/Mix.Tasks.Release.html)
or [Distillery](https://hexdocs.pm/distillery/home.html).

It assumes that [mix_systemd](https://github.com/cogini/mix_systemd) is used to generate a
systemd unit file for the application, and shares conventions with it about naming files.
See [mix_systemd](https://github.com/cogini/mix_systemd) for examples.

Here is [a complete example app](https://github.com/cogini/mix-deploy-example).

## Installation

Add `mix_deploy` to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mix_deploy, "~> 0.7.0"},
  ]
end
```

## Example

The most straightforward way to deploy an app is on a server at e.g.
[Digital Ocean](https://m.do.co/c/150575a88316). You can build and deploy on
the same machine, checking out the code on a server, building/testing, then
generating a release.  You then run scripts to set up the runtime environment,
including systemd unit scripts, extract the release to the target dir and run
it under systemd.

### Configure the app

Follow the Phoenix config process for
[deployment](https://hexdocs.pm/phoenix/deployment.html) and
[releases](https://hexdocs.pm/phoenix/releases.html). Make the app read its
config from environment variables. Create a file with these environment vars
and put it in `config/environment`.

### Configure `mix_deploy` and `mix_systemd` in `config/config.exs`

```elixir
config :mix_systemd,
  env_files: [
    # Read environment vars from file /srv/foo/etc/environment
    ["-", :deploy_dir, "/etc/environment"],
  ],
  # Set individual env vars
  env_vars: [
    "PORT=8080"
  ],
  # Run app under this OS user, default is name of app
  app_user: "app",
  app_group: "app"

config :mix_deploy,
  app_user: "app",
  app_group: "app"
  # When deploying, copy config/environment to /etc/foo/environment
  copy_files: [
    %{
      src: "config/environment",
      dst: [:deploy_dir, "/etc/environment"],
      user: "$DEPLOY_USER",
      group: "$APP_GROUP",
      mode: "640"
    },
  ],
  create_dirs: [
    %{
      path: [:deploy_dir, "/etc"],
      user: "$DEPLOY_USER",
      group: "$APP_GROUP",
      mode: "750"
    },
  ],
  # Generate these scripts in bin
  templates: [
    "init-local",
    "create-users",
    "create-dirs",
    "copy-files",
    "enable",
    "release",
    "restart",
    "rollback",
    "start",
    "stop",
  ]
```

### Initialize `mix_systemd` and `mix_deploy` and generate files.

```shell
# Initialize mix_systemd templates
mix systemd.init

# Initialize mix_deploy templates
mix deploy.init

# Create systemd unit file for app under _build/prod/systemd
MIX_ENV=prod mix systemd.generate

# Create deploy scripts project `bin` dir
MIX_ENV=prod mix deploy.generate
chmod +x bin/*
```

### Set up the system.

This creates the app OS user, directory structure under `/srv/foo`, and the
systemd unit file which supervises the app.

`deploy-init-local` is a convenience script which runs other scripts to set up
the system:

```shell
sudo bin/deploy-init-local
```

It does the following:

```shell
# Create users to run the app
bin/deploy-create-users

# Create deploy dirs under /srv/foo
bin/deploy-create-dirs

# Copy scripts used at runtime by the systemd unit
# Strictly speaking, you only need to copy scripts used at runtime
cp bin/* /srv/foo/bin

# Copy files and enable systemd unit
bin/deploy-copy-files
bin/deploy-enable
```

### Build the Elixir release

Create the release, a a tar file containing the app, the libraries it depends
on, and scripts to manage it.

```shell
MIX_ENV=prod mix release
```

### Deploy the release to the local machine:

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

### Try it out

Your app should now be running:

```shell
curl -v http://localhost:8080/
```

If it is not, have a look at the logs.

```shell
systemctl status foo
journalctl -u foo
```

If you want it to run on port 80, you can [redirect 80 to 8080
in the firewall](https://www.cogini.com/blog/port-forwarding-with-iptables/).

## Usage

First, use the `deploy.init` task to template files from the library to the
`rel/templates/deploy` directory in your project.

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
create different files based on the environment, set `bin_dir` to
`[:output_dir, "bin"]` and it will generate files under e.g. `_build/prod/deploy`.

## Configuration

The library tries to choose smart defaults, so it should require minimal
configuration for standard cases. It reads the app name from `mix.exs` and
calculates default values for its configuration parameters.

If your app is named `foo_bar`, it will create a service named `foo-bar`,
deployed to `/srv/foo-bar`, running under the user `foo-bar`.

The library doesn't generate any output scripts by default, you need to enable
them with the `templates` parameter. It can create the following scripts:

### Systemd scripts

These are wrappers on e.g. `/bin/systemctl restart foo`.  They are useful for
e.g. CodeDeploy hook scripts where we have to run a script without parameters.

* `deploy-start`: Start services
* `deploy-stop`: Stop services
* `deploy-restart`: Restart services
* `deploy-enable`: Enable systemd units

### System setup scripts

These scripts set up the target system for the application. They are useful for
local and automated deploy.

* `deploy-create-users`: Create OS accounts for app and deploy users
* `deploy-create-dirs`: Create dirs, including the release dir `/srv/foo` and
  standard dirs like `/etc/foo` if needed.

### Local deploy scripts

These scripts deploy the app to the same server as it was built on:

* `deploy-copy-files`: Copy files from `_build` to target `/srv/foo`, or to a
  staging directory for packaging
* `deploy-release`: Deploy release, extracting to a timestamped dir under
  `/srv/foo/releases`, then making a symlink from `/srv/foo/current`
* `deploy-rollback`: Rollback release, resetting the symlink to point to the
  previous release

The library also has mix tasks to deploy and roll back releases:

```shell
mix deploy.local
mix deploy.local.rollback
```

### CodeDeploy deploy scripts

These scripts run on the target machine as lifecycle hooks.

* `deploy-clean-target`: Delete files under target dir
   in preparation for deploying update
* `deploy-extract-release`: Extract release from tar
* `deploy-set-perms`: Set target file permissions so that they can be used by
  the app user

### Build server scripts

These scripts run on the build server.

* `deploy-stage-files`: Copy output files to staging directory, default `files`

### Release command scripts

These scripts set up the environment and then run release commands.
They make the config match the environment vars set at runtime in the systemd
unit. With Eixir 1.9+ you can source `/srv/foo/bin/set-env` in `rel/env.sh.eex`.
The other scripts are mainly useful with Distillery.

* `set-env`: Set up environment
* `deploy-migrate`: Migrate database on target system by
  [running a custom command](https://www.cogini.com/blog/running-ecto-migrations-in-a-release/).
* `deploy-remote-console`: Launch remote console for the app

### Runtime environment scripts

These scripts are called by the systemd unit to set get the application config
at runtime prior to starting the app. They are more most useful with Distillery.

Eixir 1.9+ mix releases support
[runtime configuration](https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-runtime-configuration)
via `config/releases.exs` and `rel/env.sh.eex`. It is more secure, however, to
separate the process of getting configuration from the app itself using
[ExecStartPre](https://www.freedesktop.org/software/systemd/man/systemd.service.html#ExecStartPre=)]).
See [mix_systemd](https://github.com/cogini/mix_systemd) for examples.

* `deploy-sync-config-s3`: Sync config files from S3 bucket to app `configuration_dir`
* `deploy-runtime-environment-file`: Create `#{runtime_dir}/environment`
  file on target from `cloud-init` metadata
* `deploy-runtime-environment-wrap`: Get runtime environment from `cloud-init`
  [metadata](https://cloudinit.readthedocs.io/en/latest/topics/instancedata.html),
  set environment vars, then launch main script.
* `deploy-set-cookie-ssm`: Get Erlang VM cookie from [AWS SSM Parameter
  Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-paramstore.html)
  and write to file.

The most useful of these is `deploy-sync-config-s3`, the rest are code you might copy into
`rel/env.sh.eex`.

### Dependencies

The generated scripts are mostly straight bash, with minimal dependencies.

* `deploy-sync-config-s3` uses the [AWS CLI](https://aws.amazon.com/cli/)
  to copy files from an S3 bucket.
* `deploy-runtime-environment-file` and `deploy-runtime-environment-wrap` use
   [jq](https://stedolan.github.io/jq/) to parse the
   [cloud-init](https://cloud-init.io/) JSON file.
* `deploy-set-cookie-ssm` uses the AWS CLI and `jq` to interact with
  Systems Manager Parameter Store.

To install `jq` on Ubuntu:

```shell
apt-get install jq
```

To install the AWS CLI from the OS package manager on Ubuntu:

```shell
apt-get install awscli
```

## Scenarios

### CodeDeploy

The library can generate lifecycle hook scripts for use with a
deployment system such as [AWS CodeDeploy](https://aws.amazon.com/codedeploy/).

```elixir
config :mix_deploy,
  app_user: "app",
  app_group: "app",
  templates: [
    "stop",
    "create-users",
    "create-dirs",
    "clean-target",
    "extract-release",
    "set-perms",
    "migrate",
    "enable",
    "start",
    "restart",
  ],
    ...
```

Here is an example
[appspec.yml](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-structure-hooks.html)
file:

```yaml
version: 0.0
os: linux
files:
  - source: bin
    destination: /srv/foo/bin
  - source: systemd
    destination: /lib/systemd/system
  - source: etc
    destination: /srv/foo/etc
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
  # ValidateService:
    - location: bin/validate-service
      timeout: 300
```

### Staging

By default, the scripts deploy the scripts as the same OS user that runs the
`mix deploy.generate` command, and run the app under an OS user with the same
name as the app.

Many scripts allow you to override environment variables at execution time. For
example, you can override the user accounts which own the files by setting the
environment vars `APP_USER`, `APP_GROUP`, and `DEPLOY_USER`.

Similarly, set `DESTDIR` and the copy script will add a prefix when copying
files. This lets you copy files to a staging directory, tar it up, then extract
it on a target machine, e.g.:

```shell
mkdir -p ~/tmp/deploy
DESTDIR=~/tmp/deploy bin/deploy-create-dirs
DESTDIR=~/tmp/deploy bin/deploy-copy-files
```

## Configuration options

The following sections describe common configuration options.
See `lib/mix/tasks/deploy.ex` for details of more obscure options.

If you need to make changes not supported by the config options,
then you can check the templates in `rel/templates/deploy`
into source control and make your own changes. Contributions are welcome!

The list of templates to generate is in the `templates` config var.
You can modify this list to remove scripts, and they won't be generated.
You can also add your own scripts and they will be run as templates with the
config vars defined.

### Basics

`app_name`: Elixir application name, an atom, from the `app` field in the `mix.exs` project.

`version`: `version` field in `mix.exs` project.

`module_name`: Elixir camel case module name version of `app_name`, e.g. `FooBar`.

`release_name`: Name of release, default `app_name`.

`ext_name`: External name, used for files and directories,
default `app_name` with underscores converted to "-", e.g. `foo-bar`.

`service_name`: Name of the systemd service, default `ext_name`.

`release_system`: `:mix | :distillery`, default `:mix`

Identifies the system used to generate the releases,
[Mix](https://hexdocs.pm/mix/Mix.Tasks.Release.html) or
[Distillery](https://hexdocs.pm/distillery/home.html).

### Users

`deploy_user`: OS user account that is used to deploy the app, e.g. own the
files and restart it. For security, this is separate from `app_user`, keeping
the runtime user from being able to modify the source files. Defaults to the
user running the script, supporting local deploy. For remote deploy, set this
to a user like `deploy` or same as the app user.

`deploy_group`: OS group account, default `deploy_user`.

`app_user`: OS user account that the app should run under. Default `deploy_user`.

`app_group`: OS group account, default `deploy_group`.

### Directories

`base_dir`: Base directory for app files on target, default `/srv`.

`deploy_dir`: Directory for app files on target, default `#{base_dir}/#{ext_name}`.

We use the
[standard app directories](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#RuntimeDirectory=),
for modern Linux systems. App files are under `/srv`, configuration under
`/etc`, transient files under `/run`, data under `/var/lib`.

Directories are named based on the app name, e.g. `/etc/#{ext_name}`.
The `dirs` variable specifies which directories the app uses.
By default, it doesn't set up anything. To enable them, configure `dirs`, e.g.:

```elixir
dirs: [
  # :runtime,       # App runtime files which may be deleted between runs, /run/#{ext_name}
  # :configuration, # App configuration, e.g. db passwords, /etc/#{ext_name}
  # :state,         # App data or state persisted between runs, /var/lib/#{ext_name}
  # :cache,         # App cache files which can be deleted, /var/cache/#{ext_name}
  # :logs,          # App external log files, not via journald, /var/log/#{ext_name}
  # :tmp,           # App temp files, /var/tmp/#{ext_name}
],
```

Recent versions of systemd (since 235) will create these directories at
start time based on the settings in the unit file. For earlier systemd
versions, `deploy-create-dirs` will create them.

For security, we set permissions to 750, more restrictive than the systemd
defaults of 755. You can configure them with variables like
`configuration_directory_mode`. See the defaults in
`lib/mix/tasks/deploy.ex`.

`systemd_version`: Sets the systemd version on the target system, default 235.
This determines which systemd features the library will enable. If you are
targeting an older OS release, you may need to change it. Here are the systemd
versions in common OS releases:

* CentOS 7: 219
* Ubuntu 16.04: 229
* Ubuntu 18.04: 237

### Additional directories

The library uses a directory structure under `deploy_dir` which supports
multiple releases, similar to [Capistrano](https://capistranorb.com/documentation/getting-started/structure/).

* `scripts_dir`: deployment scripts which e.g. start and stop the unit, default `bin`.
* `current_dir`: where the current Erlang release is unpacked or referenced by symlink, default `current`.
* `releases_dir`: where versioned releases are unpacked, default `releases`.
* `flags_dir`: dir for flag files to trigger restart, e.g. when `restart_method` is `:systemd_flag`, default `flags`.

When using multiple releases and symlinks, the deployment process works as follows:

1. Create a new directory for the release with a timestamp like
   `/srv/foo/releases/20181114T072116`.

2. Upload the new release tarball to the server and unpack it to the releases dir

3. Make a symlink from `/srv/#{ext_name}/current` to the new release dir.

4. Restart the app.

If you are only keeping a single version, then deploy it to the directory
`/srv/#{ext_name}/current`.

## Variable expansion

The following variables support variable expansion:

```elixir
expand_keys: [
  :env_files,
  :env_vars,
  :runtime_environment_service_script,
  :conform_conf_path,
  :pid_file,
  :root_directory,
  :bin_dir,
]
```

You can specify values as a list of terms, and it will look up atoms as keys in
the config. This lets you reference e.g. the deploy dir or configuration dir without
having to specify the full path, e.g. `["!", :deploy_dir, "/bin/myscript"]` gets
converted to `"!/srv/foo/bin/myscript"`.

### Environment vars

Config vars set a few common env vars:

* `mix_env`: default `Mix.env()`, sets `MIX_ENV`
* `env_lang`: default `en_US.UTF-8`, used to set `LANG`

In addition, you can set `env_vars` and `env_files` the same way
as for `mix_systemd`. The `set-env` script will then set these
varialbles the same way as they are in the systemd unit,
allowing you to run release commands with the same config, e.g. database
migrations or console. It also sets:

* `RUNTIME_DIR`: `runtime_dir`, if `:runtime` in `dirs`
* `CONFIGURATION_DIR`: `configuration_dir`, if `:configuration` in `dirs`
* `LOGS_DIR`: `logs_dir`, if `:logs` in `dirs`
* `CACHE_DIR`: `cache_dir`, if `:cache` in `dirs`
* `STATE_DIR`: `state_dir`, if `:state` in `dirs`
* `TMP_DIR`: `tmp_dir`, if `:tmp` in `dirs`

You can set additional vars using `env_vars`, e.g.:

```elixir
env_vars: [
  "PORT=8080",
]
```
You can also reference the value of other parameters by name, e.g.:

```elixir
env_vars: [
  ["RELEASE_TMP=", :runtime_dir],
]
```

You can read environment vars from files with `env_files`, e.g.:

```elixir
env_files: [
  ["-", :deploy_dir, "/etc/environment"],
  ["-", :configuration_dir, "environment"],
  ["-", :runtime_dir, "environment"],
],
```

The "-" at the beginning makes the file optional, the system will start without them.
Later values override earlier values, so you can set defaults in the release which get
overridden in the deployment or runtime environment.

With Distillery, you can generate a file under the release with an overlay in
`rel/config.exs`, e.g.:

```elixir
environment :prod do
  set overlays: [
    {:mkdir, "etc"},
    {:copy, "rel/etc/environment", "etc/environment"},
    # {:template, "rel/etc/environment", "etc/environment"}
  ]
end
```

That results in a file that would be read by:

```elixir
env_files: [
  ["-", :current_dir, "/etc/environment"],
],
```

### Starting and restarting

The following variables set systemd variables:

`service_type`: `:simple | :exec | :notify | :forking`. systemd
[Type](https://www.freedesktop.org/software/systemd/man/systemd.service.html#Type=), default `:simple`.

Modern applications don't fork, they run in the foreground and
rely on the supervisor to manage them as a daemon. This is done by setting
`service_type` to `:simple` or `:exec`. Note that in `simple` mode, systemd
doesn't actually check if the app started successfully, it just continues
starting other units. If something depends on your app being up, `:exec` may be
better.

Set `service_type` to `:forking`, and the library sets `pid_file` to
`#{runtime_directory}/#{app_name}.pid` and sets the `PIDFILE` env var to tell
the boot scripts where it is.

The Erlang VM runs pretty well in foreground mode, but traditionally runs as
as a standard Unix-style daemon, so forking might be better. Systemd
expects foregrounded apps to die when their pipe closes. See
https://elixirforum.com/t/systemd-cant-shutdown-my-foreground-app-cleanly/14581/2

`restart_method`: `:systemctl | :systemd_flag | :touch`, default `:systemctl`

The normal situation is that the app will be restarted using e.g.
`systemctl restart foo`.

With `:systemd_flag`, an additional systemd unit file watches for
changes to a flag file and restarts the main unit. This allows updates to be
pushed to the target machine by an unprivileged user account which does not
have permissions to restart processes. Touch the file `#{flags_dir}/restart.flag`
and systemd will restart the unit.  See `mix_systemd` for details.

With `:touch`, the app itself watches the file `#{flags_dir}/restart.flag`.
If it changes, the app shuts itself down, relying on systemd to notice and restart it.

`sudo_deploy`: Creates `/etc/sudoers.d/#{ext_name}` file which allows the deploy
user to start/stop/restart the app using sudo. Default `false`. Note that
when you must call systemctl with the full path, e.g. `sudo /bin/systemctl restart foo`
for this to work.

`sudo_app`: Creates `/etc/sudoers.d/#{ext_name}` file allowing the app user
user to start/stop/restart the app using sudo. Default `false`.

### Configuration examples

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

We need to bootstrap the config process, so we use a different environment file
from the main config.

```shell
mkdir -p rel/etc
echo "CONFIG_S3_BUCKET=cogini-foo-dev-app-config" >> rel/etc/environment
```

Set `exec_start_pre` in the `mix_systemd` config:

```elixir
config :mix_systemd,
  app_user: "app",
  app_group: "app",
  # systemd runs this before starting the app as root
  exec_start_pre: [
    ["!", :deploy_dir, "/bin/deploy-sync-config-s3"]
  ],
  dirs: [
    # Create /etc/foo
    :configuration,
    # Create /run/foo
    :runtime,
  ],
  # systemd should not clean up /run/foo
  runtime_directory_preserve: "yes",
  # Load env from /srv/foo/etc/environment and /etc/foo/environment
  env_files: [
    ["-", :deploy_dir, "/etc/environment"],
    ["-", :configuration_dir, "/environment"],
  ],
  # deploy-copy-files will copy the env file to /srv/foo/etc
  # more likely it is done by e.g. appspec.yml
  copy_files: [
    %{
      src: "rel/etc/environment",
      dst: [:deploy_dir, "/etc"],
      user: "$DEPLOY_USER",
      group: "$APP_GROUP",
      mode: "640"
    },
  ],
  env_vars: [
    # Temp files are in /run/foo
    ["RELEASE_TMP=", :runtime_dir],
  ]

config :mix_deploy,
  app_user: "app",
  app_group: "app"
  templates: [
    "init-local",
    "create-users",
    "create-dirs",
    "copy-files",
    "enable",
    "release",
    "restart",
    "rollback",
    "start",
    "stop",

    "sync-config-s3",
  ],
  dirs: [
    :configuration,
    :runtime,
  ],
  # Set env config in e.g. deploy-set-env to match above.
  env_files: [
    ["-", :deploy_dir, "/etc/environment"],
    ["-", :configuration_dir, "/environment"],
  ]
  env_vars: [
    ["RELEASE_TMP=", :runtime_dir],
  ]
```

For security, the app only has read-only access to its config files, and
`/etc/foo` has ownership `deploy:foo` and mode 750. We prefix the command
with "!" so it runs with elevated permissions, not as the `foo` user.

We need to set the `CONFIG_S3_BUCKET` variable in the environment so that
`deploy-sync-config-s3` can use it. We can set it in `env_vars`
or put it in the file `/etc/foo/environment`.

* `/srv/foo/etc/environment` settings are configured at deploy time.
* `/etc/foo/environment` settings might come from an S3
bucket.
* `/run/foo/environment` settings might be generated dynamically, e.g. getting
  the IP address.

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

See [mix_systemd](https://github.com/cogini/mix_systemd) for more examples.

