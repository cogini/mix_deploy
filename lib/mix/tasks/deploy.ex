defmodule Mix.Tasks.Deploy do
  # Directory where `mix deploy.generate` stores output files,
  # e.g. _build/prod/deploy
  @output_dir "deploy"

  # Directory where `mix deploy.init` copies templates in user project
  @template_dir "rel/templates/deploy"

  @spec parse_args(OptionParser.argv()) :: Keyword.t
  def parse_args(argv) do
    opts = [strict: [version: :string]]
    {overrides, _} = OptionParser.parse!(argv, opts)

    user_config = Application.get_all_env(:mix_deploy)
    mix_config = Mix.Project.config()

    # Elixir app name, from mix.exs
    app_name = mix_config[:app]

    # External name, used for files and directories
    ext_name = app_name
               |> to_string
               |> String.replace("_", "-")

    # Name of systemd unit
    service_name = ext_name

    # Elixir camel case module name version of snake case app name
    module_name = app_name
                  |> to_string
                  |> String.split("_")
                  |> Enum.map(&String.capitalize/1)
                  |> Enum.join("")

    base_dir = user_config[:base_dir] || "/srv"

    build_path = Mix.Project.build_path()

    {{cur_user, _cur_uid}, {cur_group, _cur_gid}, _} = MixDeploy.User.get_id()

    defaults = [
      # Elixir application name
      app_name: app_name,

      # Elixir module name in camel case
      module_name: module_name,

      # Name of release
      release_name: app_name,

      # External name, used for files and directories
      ext_name: ext_name,

      # Name of service
      service_name: service_name,

      # OS user to own files
      deploy_user: cur_user,
      deploy_group: cur_group,

      # App version
      version: mix_config[:version],

      # Base directory on target system, e.g. /srv
      base_dir: base_dir,

      # Directory for release files on target
      deploy_dir: "#{base_dir}/#{ext_name}",

      # Target systemd version
      # systemd_version: 219, # CentOS 7
      # systemd_version: 229, # Ubuntu 16.04
      # systemd_version: 237, # Ubuntu 18.04
      systemd_version: 235,

      dirs: [
        # :runtime,       # App runtime files which may be deleted between runs, /run/#{ext_name}
        # :configuration, # Config files, Erlang cookie
        # :logs,          # External log file, not journald
        # :cache,         # App cache files which can be deleted
        # :state,         # App state persisted between runs
        # :tmp,           # App temp files
      ],

      # Standard directory locations for under systemd for various purposes.
      # https://www.freedesktop.org/software/systemd/man/systemd.exec.html#RuntimeDirectory=
      #
      # Recent versions of systemd (since 235) will create directories if they
      # don't exist if they are configured in the unit file.
      #
      # For security, modes are tighter than the systemd default of 755.
      # Note that these are strings, not integers, as they are actually octal.
      cache_directory: service_name,
      cache_directory_base: "/var/cache",
      cache_directory_mode: "750",
      configuration_directory: service_name,
      configuration_directory_base: "/etc",
      configuration_directory_mode: "750",
      logs_directory: service_name,
      logs_directory_base: "/var/log",
      logs_directory_mode: "750",
      runtime_directory: service_name,
      runtime_directory_base: "/run",
      runtime_directory_mode: "750",
      # Whether to preserve the runtime dir on app restart
      # https://www.freedesktop.org/software/systemd/man/systemd.exec.html#RuntimeDirectoryPreserve=
      runtime_directory_preserve: "no", # "no" | "yes" | "restart"
      state_directory: service_name,
      state_directory_base: "/var/lib",
      state_directory_mode: "750",
      tmp_directory: service_name,
      tmp_directory_base: "/var/tmp",
      tmp_directory_mode: "750",

      # Elixir 1.9+ mix releases or Distillery
      release_system: :mix, # :mix | :distillery

      # How service is restarted on update
      restart_method: :systemctl, # :systemctl | :systemd_flag | :touch

      # Mix build_path
      build_path: build_path,

      # Staging output directory for generated files
      output_dir: Path.join(build_path, @output_dir),

      # Directory where scripts will be generated in build
      # Default is top level bin dir in project
      # Set to [:output_dir, "bin"] to generate under _build/prod/deploy/bin
      bin_dir: "bin",

      # Directory with templates which override defaults
      template_dir: @template_dir,

      mix_env: Mix.env(),

      # LANG environment var for running scripts
      env_lang: "C.UTF-8",

      # Environment files to read, e.g.
      # env_files: [
      #   ["-", :configuration_dir, "environment"],
      # ],
      # The "-" at the beginning means that the file is optional
      env_files: [
        ["-", :configuration_dir],
      ],

      # Misc env vars to set, e.g.
      # env_vars: [
      #  "REPLACE_OS_VARS=true",
      #  ["RELEASE_MUTABLE_DIR=", :runtime_dir]
      # ]
      env_vars: [],

      # Whether to create /etc/suders.d file allowing deploy an/or app user to
      # restart app
      sudo_deploy: false,
      sudo_app: false,

      runtime_environment_service_script: nil,

      # Path to conform config file
      conform_conf_path: nil,

      # Prefix for generated script files
      target_prefix: "deploy-",

      # Files to generate
      templates: [
        # Systemd wrappers
        # "start",
        # "stop",
        # "restart",
        # "enable",

        # System setup
        # "create-users",
        # "create-dirs",

        # Local deploy
        # "init-local",
        # "copy-files",
        # "release",
        # "rollback",

        # CodeDeploy
        # "clean-target",
        # "extract-release",
        # "set-perms",

        # CodeBuild
        # "stage-files",
        # "sync-assets-s3",

        # Release commands
        # "set-env",
        # "remote-console",
        # "migrate",

        # Runtime environment
        # "sync-config-s3",
        # "runtime-environment-file",
        # "runtime-environment-wrap",
        # "set-cookie-ssm",
      ],

      # Config keys which have variable expansion
      expand_keys: [
        :env_files,
        :env_vars,
        :runtime_environment_service_script,
        :conform_conf_path,
        :pid_file,
        :root_directory,
        :bin_dir
      ],

      # Add your keys here
      expand_keys_extra: []
    ]

    # Override values from user config
    cfg = defaults
          |> Keyword.merge(user_config)
          |> Keyword.merge(overrides)

    # Calcualate values from other things
    cfg = Keyword.merge([
      releases_dir: cfg[:releases_dir] || Path.join(cfg[:deploy_dir], "releases"),
      scripts_dir: cfg[:scripts_dir] || Path.join(cfg[:deploy_dir], "bin"),
      flags_dir: cfg[:flags_dir] || Path.join(cfg[:deploy_dir], "flags"),
      current_dir: cfg[:current_dir] || Path.join(cfg[:deploy_dir], "current"),

      runtime_dir: cfg[:runtime_dir] || Path.join(cfg[:runtime_directory_base], cfg[:runtime_directory]),
      configuration_dir: cfg[:configuration_dir] || Path.join(cfg[:configuration_directory_base], cfg[:configuration_directory]),
      logs_dir: cfg[:logs_dir] || Path.join(cfg[:logs_directory_base], cfg[:logs_directory]),
      tmp_dir: cfg[:logs_dir] || Path.join(cfg[:tmp_directory_base], cfg[:tmp_directory]),
      state_dir: cfg[:state_dir] || Path.join(cfg[:state_directory_base], cfg[:state_directory]),
      cache_dir: cfg[:cache_dir] || Path.join(cfg[:cache_directory_base], cfg[:cache_directory]),

      # Loation of pid file when running as a daemon
      pid_file: cfg[:pid_file] || Path.join([cfg[:runtime_directory_base], cfg[:runtime_directory], "#{app_name}.pid"]),

      # Chroot dir
      root_directory: cfg[:root_directory] || Path.join(cfg[:deploy_dir], "current"),

      # OS user that app runs as
      app_user: cfg[:deploy_user],
      app_group: cfg[:deploy_group],
    ], cfg)

    # Mix.shell.info "cfg: #{inspect cfg}"

    expand_keys(cfg, cfg[:expand_keys] ++ cfg[:expand_keys_extra])
  end

  @doc "Expand cfg vars in keys"
  @spec expand_keys(Keyword.t, list(atom)) :: Keyword.t
  def expand_keys(cfg, keys) do
    Enum.reduce(Keyword.take(cfg, keys), cfg,
      fn({key, value}, acc) ->
        Keyword.put(acc, key, expand_value(value, acc))
      end)
  end

  @doc "Expand vars in value or list of values"
  @spec expand_value(term, Keyword.t) :: binary
  def expand_value(values, cfg) when is_list(values) do
    Enum.map(values, &expand_vars(&1, cfg))
  end
  def expand_value(value, cfg), do: expand_vars(value, cfg)

  @doc "Expand references in values"
  @spec expand_vars(term, Keyword.t) :: binary
  def expand_vars(value, _cfg) when is_binary(value), do: value
  def expand_vars(nil, _cfg), do: ""
  def expand_vars(key, cfg) when is_atom(key) do
    case Keyword.fetch(cfg, key) do
      {:ok, value} ->
        expand_vars(value, cfg)
      :error ->
        to_string(key)
    end
  end
  def expand_vars(terms, cfg) when is_list(terms) do
    terms
    |> Enum.map(&expand_vars(&1, cfg))
    |> Enum.join("")
  end
  def expand_vars(value, _cfg), do: to_string(value)

end

defmodule Mix.Tasks.Deploy.Init do
  @moduledoc """
  Initialize template files.

  ## Command line options

    * `--template_dir` - target directory

  ## Usage

      # Copy default templates into your project
      mix deploy.init
  """
  @shortdoc "Initialize template files"
  use Mix.Task

  @app :mix_deploy

  @spec run(OptionParser.argv()) :: no_return
  def run(args) do
    cfg = Mix.Tasks.Deploy.parse_args(args)

    template_dir = cfg[:template_dir]
    app_dir = Application.app_dir(@app, ["priv", "templates"])

    :ok = File.mkdir_p(template_dir)
    {:ok, _files} = File.cp_r(app_dir, template_dir)
  end

end

defmodule Mix.Tasks.Deploy.Generate do
  @moduledoc """
  Create deploy scripts and files for project.

  ## Usage

      # Create scripts and files for MIX_ENV=prod
      MIX_ENV=prod mix deploy.generate
  """
  @shortdoc "Create deploy scripts and files"
  use Mix.Task

  alias MixDeploy.Templates

  @spec run(OptionParser.argv()) :: no_return
  def run(args) do
    cfg = Mix.Tasks.Deploy.parse_args(args)
    ext_name = cfg[:ext_name]
    output_dir = cfg[:output_dir]

    create_flags_dir = cfg[:restart_method] in [:systemd_flag, :touch]
    # app needs to be able to delete the flag file at runtime
    flags_dir_mode = if cfg[:restart_method] == :touch, do: "770", else: "750"

    dirs = [
      {true, cfg[:deploy_dir], "$DEPLOY_USER", "$APP_GROUP", "750", "Base dir"},
      {true, cfg[:releases_dir], "$DEPLOY_USER", "$APP_GROUP", "750", "Releases"},
      {true, cfg[:scripts_dir], "$DEPLOY_USER", "$APP_GROUP", "750", "Target scripts"},
      {create_flags_dir, cfg[:flags_dir], "$DEPLOY_USER", "$APP_GROUP", flags_dir_mode, "Flag files"}
    ] ++
    if cfg[:systemd_version] < 235 do
      # systemd will automatically create directories in newer versions
      # https://www.freedesktop.org/software/systemd/man/systemd.exec.html#RuntimeDirectory=
      [
        {:runtime in cfg[:dirs], cfg[:runtime_dir], "$APP_USER", "$APP_GROUP", cfg[:runtime_directory_mode], "systemd RuntimeDirectory"},
        {:configuration in cfg[:dirs], cfg[:configuration_dir], "$DEPLOY_USER", "$APP_GROUP", cfg[:confguration_directory_mode], "systemd ConfigurationDirectory"},
        {:logs  in cfg[:dirs], cfg[:logs_dir],  "$APP_USER", "$APP_GROUP", cfg[:logs_directory_mode], "systemd LogsDirectory"},
        {:state in cfg[:dirs], cfg[:state_dir], "$APP_USER", "$APP_GROUP", cfg[:state_directory_mode], "systemd StateDirectory"},
        {:cache in cfg[:dirs], cfg[:cache_dir], "$APP_USER", "$APP_GROUP", cfg[:cache_directory_mode], "systemd CacheDirectory"},
        # Better handled by PrivateTmp in newer systemd
        {:tmp in cfg[:dirs], cfg[:tmp_dir], "$APP_USER", "$APP_GROUP", cfg[:tmp_directory_mode], "Temp directory"},
      ]
    else
      []
    end

    files = [
      # {"bin/deploy", Path.join(cfg[:scripts_dir], "deploy"), "$DEPLOY_USER", "$APP_GROUP", 0o750},
      # {"bin/remote_console", Path.join(cfg[:scripts_dir], "remote_console"), "$DEPLOY_USER", "$APP_GROUP", 0o750},
    ]

    vars = cfg ++ [create_dirs: dirs, copy_files: files]

    for template <- cfg[:templates], do: write_template(vars, cfg[:bin_dir], template)

    if cfg[:sudo_deploy] or cfg[:sudo_app] do
      # Give deploy and/or app user ability to run start/stop commands via sudo
      # root:root 600
      write_template(cfg, Path.join(output_dir, "/etc/sudoers.d"), "sudoers", ext_name)
    end
  end

  defp write_template(cfg, dest_dir, template), do: write_template(cfg, dest_dir, template, template)

  defp write_template(cfg, dest_dir, template, file) do
    output_file = cfg[:target_prefix] <> file
    target_file = Path.join(dest_dir, output_file)
    Mix.shell.info "Generating #{target_file} from template #{template}"
    Templates.write_template(cfg, dest_dir, template, output_file)
  end
end

defmodule Mix.Tasks.Deploy.Local do
  @shortdoc "Deploy release to local machine"

  @moduledoc """
  This task deploys a Distillery release to the local machine.

  It extracts the release tar to a timestamped directory like
  `/srv/:app/releases/20170619175601`, then makes a symlink
  from `/srv/:app/current` to it.

  This module looks for configuration in the mix project, to get the app and version,
  and under the application environment under `mix_deploy`.

  * `base_dir` sets the base directory, default `/srv`.
  * `deploy_dir` sets the target directory completely manually, ignoring `base_dir` and `app`.
  ```
  """

  use Mix.Task

  @spec run(OptionParser.argv()) :: no_return
  def run(args) do
    # IO.puts (inspect args)
    config = Mix.Tasks.Deploy.parse_args(args)
    deploy_release(config)
  end

  @spec deploy_release(Keyword.t) :: no_return
  def deploy_release(cfg) do
    release_dir = Path.join(cfg[:releases_dir], create_timestamp())
    Mix.shell.info "Deploying release to #{release_dir}"
    :ok = File.mkdir_p(release_dir)

    app = to_string(cfg[:app_name])
    tar_file = Path.join([cfg[:build_path], "rel", app, "releases", cfg[:version], "#{app}.tar.gz"])
    Mix.shell.info "Extracting tar #{tar_file}"
    :ok = :erl_tar.extract(to_charlist(tar_file), [{:cwd, release_dir}, :compressed])

    current_link = cfg[:current_path]
    if File.exists?(current_link) do
      :ok = File.rm(current_link)
    end
    :ok = File.ln_s(release_dir, current_link)
  end

  def create_timestamp do
    {{year, month, day}, {hour, minute, second}} = :calendar.now_to_universal_time(:os.timestamp())
    timestamp = :io_lib.format("~4..0B~2..0B~2..0B~2..0B~2..0B~2..0B", [year, month, day, hour, minute, second])
    timestamp |> List.flatten |> to_string
  end

end

defmodule Mix.Tasks.Deploy.Local.Rollback do
  @moduledoc """
  Update current symlink to point to the previous release directory.
  """

  use Mix.Task

  def run(args) do
    cfg = Mix.Tasks.Deploy.parse_args(args)

    dirs = cfg[:releases_path] |> File.ls! |> Enum.sort |> Enum.reverse

    rollback(dirs, cfg)
  end

  @spec rollback([Path.t], Keyword.t) :: :ok
  defp rollback([_current, prev | _rest], cfg) do
    release_path = Path.join(cfg[:releases_path], prev)
    current_dir = cfg[:current_dir]
    Mix.shell.info "Making link from #{release_path} to #{current_dir}"
    :ok = remove_link(current_dir)
    :ok = File.ln_s(release_path, current_dir)
  end
  defp rollback(dirs, _cfg) do
    Mix.shell.info "Nothing to roll back to: releases = #{inspect dirs}"
    :ok
  end

  @spec remove_link(Path.t) :: :ok | {:error, :file.posix()}
  defp remove_link(current_path) do
    case File.read_link(current_path) do
      {:ok, target} ->
        Mix.shell.info "Removing link from #{target} to #{current_path}"
        File.rm(current_path)
      {:error, _reason} ->
        Mix.shell.info "No current link #{current_path}"
        :ok
    end
  end
end
