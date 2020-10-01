defmodule Mix.Tasks.Deploy do
  @moduledoc false
  # Directory under _build where module stores generated files
  @output_dir "deploy"

  # Name of directory for project templates
  @template_dir "rel/templates/deploy"

  alias MixDeploy.User

  @spec parse_args(OptionParser.argv()) :: Keyword.t()
  def parse_args(argv) do
    opts = [
      strict: [
        version: :string
      ]
    ]

    {overrides, _} = OptionParser.parse!(argv, opts)

    mix_config = Mix.Project.config()
    user_config = Application.get_all_env(:mix_deploy)

    app_name = mix_config[:app]

    ext_name =
      app_name
      |> to_string
      |> String.replace("_", "-")

    service_name = ext_name

    module_name =
      app_name
      |> to_string
      |> String.split("_")
      |> Enum.map(&String.capitalize/1)
      |> Enum.join("")

    base_dir = user_config[:base_dir] || "/srv"

    build_path = Mix.Project.build_path()

    {{cur_user, _cur_uid}, {cur_group, _cur_gid}, _} = User.get_id()

    defaults = [
      mix_env: Mix.env(),

      # LANG environment var for running scripts
      env_lang: "en_US.UTF-8",

      # Elixir application name
      app_name: app_name,

      # Elixir module name in camel case
      module_name: module_name,

      # Name of directories
      ext_name: ext_name,

      # Name of service
      service_name: service_name,

      # App version
      version: mix_config[:version],

      # Base directory on target system
      base_dir: base_dir,

      # Directory for release files on target
      deploy_dir: "#{base_dir}/#{ext_name}",

      # Mix build_path
      build_path: build_path,

      # Staging output directory for generated files
      output_dir: Path.join(build_path, @output_dir),

      # Generate script files under build_path
      # Otherwise generate scripts under project top "bin" dir
      output_dir_per_env: false,

      # Directory with templates which override defaults
      template_dir: @template_dir,

      # OS user to own files and run app
      deploy_user: cur_user,
      deploy_group: cur_group,

      # Whether app uses conform
      conform: false,
      conform_conf_path: "/etc/#{ext_name}/#{app_name}.conf",

      # Target systemd version
      # CentOS 7
      systemd_version: 219,
      # systemd_version: 229, # Ubuntu 16.04

      # Whether to create /etc/suders.d file allowing deploy an/or app user to
      # restart app
      sudo_deploy: false,
      sudo_app: false,
      # :systemd_flag | :systemctl | :touch
      restart_method: :systemctl,
      # enable and start app runtime-environment.service
      runtime_environment_service: false,
      dirs: [
        # RELEASE_TMP, RELEASE_MUTABLE_DIR, runtime-environment
        :runtime,
        # Config files, Erlang cookie
        :configuration
        # :logs,          # External log file, not journald
        # :cache,         # App cache files which can be deleted
        # :state,         # App state persisted between runs
        # :tmp,           # App temp files
      ],

      # Standard directory locations for under systemd for various purposes.
      # https://www.freedesktop.org/software/systemd/man/systemd.exec.html#RuntimeDirectory=
      #
      # Recent versions of systemd will create directories if they don't exist
      # if they are specified in the unit file.
      #
      # For security, we default to modes which are tighter than the systemd
      # default of 755.
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
      runtime_directory_preserve: "no",
      state_directory: service_name,
      state_directory_base: "/var/lib",
      state_directory_mode: "750",
      tmp_directory: service_name,
      tmp_directory_base: "/var/tmp",
      tmp_directory_mode: "750",
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
        "deploy-stage-files",
        "deploy-stop",
        "deploy-sync-config-s3",
        "deploy-sync-assets-s3",
        "deploy-noop",
        "deploy-rotate-dd-secrets"
      ]
    ]

    cfg =
      defaults
      |> Keyword.merge(user_config)
      |> Keyword.merge(overrides)

    # Default OS user and group names
    cfg =
      Keyword.merge(
        [
          app_user: cfg[:deploy_user],
          app_group: cfg[:deploy_group]
        ],
        cfg
      )

    # Mix.shell.info "cfg: #{inspect cfg}"

    # Data calculated from other things
    Keyword.merge(
      [
        releases_dir: Path.join(cfg[:deploy_dir], "releases"),
        scripts_dir: Path.join(cfg[:deploy_dir], "bin"),
        flags_dir: Path.join(cfg[:deploy_dir], "flags"),
        current_dir: Path.join(cfg[:deploy_dir], "current"),
        bin_dir:
          if cfg[:output_dir_per_env] do
            Path.join(cfg[:output_dir], "bin")
          else
            "bin"
          end,
        runtime_dir: Path.join(cfg[:runtime_directory_base], cfg[:runtime_directory]),
        configuration_dir:
          Path.join(cfg[:configuration_directory_base], cfg[:configuration_directory]),
        logs_dir: Path.join(cfg[:logs_directory_base], cfg[:logs_directory]),
        tmp_dir: Path.join(cfg[:tmp_directory_base], cfg[:tmp_directory]),
        state_dir: Path.join(cfg[:state_directory_base], cfg[:state_directory]),
        cache_dir: Path.join(cfg[:cache_directory_base], cfg[:cache_directory])
      ],
      cfg
    )
  end
end

defmodule Mix.Tasks.Deploy.Init do
  @moduledoc """
  Initialize template files.

  ## Usage

      # Copy default templates into your project
      mix deploy.init
  """
  @shortdoc "Initialize template files"
  use Mix.Task
  alias Mix.Tasks.Deploy

  @app :mix_deploy

  @spec run(OptionParser.argv()) :: no_return
  def run(args) do
    cfg = Deploy.parse_args(args)

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

  alias Mix.Tasks.Deploy
  alias MixDeploy.Templates

  def flags_dir(cfg) do
    if cfg[:restart_method] in [:systemd_flag, :touch] do
      perms =
        if cfg[:restart_method] == :touch do
          # app needs to be able to delete file at runtime
          0o770
        else
          0o750
        end

      [{cfg[:flags_dir], cfg[:deploy_user], cfg[:app_group], perms, "Flag files"}]
    else
      []
    end
  end

  @spec run(OptionParser.argv()) :: no_return
  def run(args) do
    cfg = Deploy.parse_args(args)
    ext_name = cfg[:ext_name]
    output_dir = cfg[:output_dir]

    # deploy_user = cfg[:deploy_user]
    # # deploy_group = cfg[:deploy_group]
    # app_user = cfg[:app_user]
    # app_group = cfg[:app_group]

    create_flags_dir = cfg[:restart_method] in [:systemd_flag, :touch]

    flags_dir_perms =
      if cfg[:restart_method] == :touch do
        # app needs to be able to delete the flag file at runtime
        0o770
      else
        0o750
      end

    dirs =
      [
        {true, cfg[:deploy_dir], "$DEPLOY_USER", "$APP_GROUP", 0o750, "Base dir"},
        {true, cfg[:releases_dir], "$DEPLOY_USER", "$APP_GROUP", 0o750, "Releases"},
        {true, cfg[:scripts_dir], "$DEPLOY_USER", "$APP_GROUP", 0o750, "Target scripts"},
        {create_flags_dir, cfg[:flags_dir], "$DEPLOY_USER", "$APP_GROUP", flags_dir_perms,
         "Flag files"}
      ] ++
        if cfg[:systemd_version] < 235 do
          # systemd will automatically create directories in newer versions
          # https://www.freedesktop.org/software/systemd/man/systemd.exec.html#RuntimeDirectory=
          [
            # We always need runtime dir, as we use it for RELEASE_TMP
            {true, cfg[:runtime_dir], "$APP_USER", "$APP_GROUP", 0o750,
             "systemd RuntimeDirectory"},

            # Needed for exernal config file
            {:configuration in cfg[:dirs], cfg[:configuration_dir], "$DEPLOY_USER", "$APP_GROUP",
             0o750, "systemd ConfigurationDirectory"},
            {:logs in cfg[:dirs], cfg[:logs_dir], "$APP_USER", "$APP_GROUP", 0o700,
             "systemd LogsDirectory"},
            {:state in cfg[:dirs], cfg[:state_dir], "$APP_USER", "$APP_GROUP", 0o700,
             "systemd StateDirectory"},
            {:cache in cfg[:dirs], cfg[:cache_dir], "$APP_USER", "$APP_GROUP", 0o700,
             "systemd CacheDirectory"},

            # Better handled by PrivateTmp in newer systemd
            {:tmp in cfg[:dirs], cfg[:tmp_dir], "$APP_USER", "$APP_GROUP", 0o700,
             "Temp directory"}
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

  defp write_template(cfg, dest_dir, template),
    do: write_template(cfg, dest_dir, template, template)

  defp write_template(cfg, dest_dir, template, file) do
    target_file = Path.join(dest_dir, file)
    Mix.shell().info("Generating #{target_file} from template #{template}")
    Templates.write_template(cfg, dest_dir, template, file)
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

  alias Mix.Tasks.Deploy

  @spec run(OptionParser.argv()) :: no_return
  def run(args) do
    # IO.puts (inspect args)
    config = Deploy.parse_args(args)
    deploy_release(config)
  end

  @spec deploy_release(Keyword.t()) :: no_return
  def deploy_release(cfg) do
    release_dir = Path.join(cfg[:releases_dir], create_timestamp())
    Mix.shell().info("Deploying release to #{release_dir}")
    :ok = File.mkdir_p(release_dir)

    app = to_string(cfg[:app_name])

    tar_file =
      Path.join([cfg[:build_path], "rel", app, "releases", cfg[:version], "#{app}.tar.gz"])

    Mix.shell().info("Extracting tar #{tar_file}")
    :ok = :erl_tar.extract(to_charlist(tar_file), [{:cwd, release_dir}, :compressed])

    current_link = cfg[:current_path]

    if File.exists?(current_link) do
      :ok = File.rm(current_link)
    end

    :ok = File.ln_s(release_dir, current_link)
  end

  def create_timestamp do
    {{year, month, day}, {hour, minute, second}} =
      :calendar.now_to_universal_time(:os.timestamp())

    timestamp =
      :io_lib.format("~4..0B~2..0B~2..0B~2..0B~2..0B~2..0B", [
        year,
        month,
        day,
        hour,
        minute,
        second
      ])

    timestamp |> List.flatten() |> to_string
  end
end

defmodule Mix.Tasks.Deploy.Local.Rollback do
  @moduledoc """
  Update current symlink to point to the previous release directory.
  """

  use Mix.Task

  alias Mix.Tasks.Deploy

  def run(args) do
    cfg = Deploy.parse_args(args)

    dirs = cfg[:releases_path] |> File.ls!() |> Enum.sort() |> Enum.reverse()

    rollback(dirs, cfg)
  end

  @spec rollback([Path.t()], Keyword.t()) :: :ok
  defp rollback([_current, prev | _rest], cfg) do
    release_path = Path.join(cfg[:releases_path], prev)
    current_dir = cfg[:current_dir]
    Mix.shell().info("Making link from #{release_path} to #{current_dir}")
    :ok = remove_link(current_dir)
    :ok = File.ln_s(release_path, current_dir)
  end

  defp rollback(dirs, _cfg) do
    Mix.shell().info("Nothing to roll back to: releases = #{inspect(dirs)}")
    :ok
  end

  @spec remove_link(Path.t()) :: :ok | {:error, :file.posix()}
  defp remove_link(current_path) do
    case File.read_link(current_path) do
      {:ok, target} ->
        Mix.shell().info("Removing link from #{target} to #{current_path}")
        File.rm(current_path)

      {:error, _reason} ->
        Mix.shell().info("No current link #{current_path}")
        :ok
    end
  end
end
