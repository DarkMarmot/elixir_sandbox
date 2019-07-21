defmodule SandboxTest do
  use ExUnit.Case
  doctest Sandbox

  test "greets the world" do
    assert Sandbox.hello() == :world
  end
end
