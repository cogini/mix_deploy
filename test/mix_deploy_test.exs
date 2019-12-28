defmodule MixDeployTest do
  use ExUnit.Case

  test "create_config/2" do
    mix_config = Mix.Project.config()
    user_config = [base_dir: "/opt"]
    cfg = Mix.Tasks.Deploy.create_config(mix_config, user_config)

    assert cfg[:app_name] == :mix_deploy
    assert cfg[:ext_name] == "mix-deploy"
    assert cfg[:module_name] == "MixDeploy"
    assert cfg[:deploy_dir] == "/opt/mix-deploy"
    assert cfg[:releases_dir] == "/opt/mix-deploy/releases"
    assert cfg[:configuration_dir] == "/etc/mix-deploy"
    assert cfg[:pid_file] == "/run/mix-deploy/mix_deploy.pid"
  end

  describe "expand_vars/2" do
    test "nil returns empty string" do
      assert Mix.Tasks.Deploy.expand_vars(nil, []) == ""
    end
    test "string returns itself" do
      assert Mix.Tasks.Deploy.expand_vars("", []) == ""
      assert Mix.Tasks.Deploy.expand_vars("foo", []) == "foo"
    end
    test "atom returns value from cfg" do
      assert Mix.Tasks.Deploy.expand_vars(:foo, [foo: "bar"]) == "bar"
    end
    test "atom returns value recursively" do
      assert Mix.Tasks.Deploy.expand_vars(:foo, [foo: :bar, bar: "baz"]) == "baz"
    end
    test "unknown atom returns string value of atom" do
      assert Mix.Tasks.Deploy.expand_vars(:foo, []) == "foo"
    end
    test "integers are converted to string" do
      assert Mix.Tasks.Deploy.expand_vars(42, []) == "42"
    end
    test "list of terms returns string value" do
      assert Mix.Tasks.Deploy.expand_vars(["one", "two", "three"], []) == "onetwothree"
    end
    test "list of terms expands vars" do
      assert Mix.Tasks.Deploy.expand_vars([:deploy_dir, "/etc"], [deploy_dir: "/srv/foo"]) == "/srv/foo/etc"
      assert Mix.Tasks.Deploy.expand_vars(["!", :deploy_dir, "/bin/sync"], [deploy_dir: "/srv/foo"]) == "!/srv/foo/bin/sync"
    end
    test "handles env vars" do
      assert Mix.Tasks.Deploy.expand_vars(["RELEASE_MUTABLE_DIR=", :runtime_dir], [runtime_dir: "/run/foo"]) == "RELEASE_MUTABLE_DIR=/run/foo"
    end
  end
end
