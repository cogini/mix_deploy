defmodule MixDeployLocalTest do
  use ExUnit.Case
  doctest MixDeployLocal

  test "greets the world" do
    assert MixDeployLocal.hello() == :world
  end
end
