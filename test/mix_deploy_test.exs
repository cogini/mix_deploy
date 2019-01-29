defmodule MixDeployTest do
  use ExUnit.Case
  doctest MixDeploy

  test "greets the world" do
    assert MixDeploy.hello() == :world
  end
end
