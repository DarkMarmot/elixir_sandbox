defmodule SandboxTest do
  use ExUnit.Case
  doctest Sandbox

  def mobility(state) do
    state
    |> Sandbox.set!("feeling", "sad")
    |> Sandbox.set!("hunger", 7)
    |> Sandbox.expose_elixir("feels", fn p -> to_string(p) <> " feels" end)
  end

  test "can set value" do
    output =
      Sandbox.init()
      |> Sandbox.set!("some_variable", "some_value")
      |> Sandbox.eval!("return some_variable")

    assert output == "some_value"
  end

  test "can set value at path" do
    output =
      Sandbox.init()
      |> Sandbox.set!("some_table", [])
      |> Sandbox.set!(["some_table", "some_variable"], "some_value")
      |> Sandbox.eval!("return some_table.some_variable")

    assert output == "some_value"
  end

  test "can set value at path with dot notation" do
    output =
      Sandbox.init()
      |> Sandbox.set!("some_table", [])
      |> Sandbox.set!("some_table.some_variable", "some_value")
      |> Sandbox.eval!("return some_table.some_variable")

    assert output == "some_value"
  end

  test "can call function at path" do
    output =
      Sandbox.init()
      |> Sandbox.run_file!("test/lua/bunny.lua")
      |> Sandbox.eval_function!(["speak"], ["bunny"])

    assert output == "silence"
  end

  test "can call function at path as string" do
    output =
      Sandbox.init()
      |> Sandbox.run_file!("test/lua/bunny.lua")
      |> Sandbox.eval_function!("speak", ["cow"], 0)

    assert output == "moo"
  end

  test "can call function at path with single arg wrapped as array" do
    output =
      Sandbox.init()
      |> Sandbox.run_file!("test/lua/bunny.lua")
      |> Sandbox.eval_function!("speak", "dog", 100_000)

    assert output == "woof"
  end

  test "can handle chunks" do
    state = Sandbox.init()

    code =
      state
      |> Sandbox.chunk!("return 7")

    output = Sandbox.eval!(state, code)
    assert output == 7
  end

  test "can chunk against file defined functions" do
    state = Sandbox.init()

    code =
      state
      |> Sandbox.chunk!("return 7")

    output = Sandbox.eval!(state, code)
    assert output == 7
  end

  test "can expose Elixir function" do
    state = Sandbox.init()

    output =
      state
      |> Sandbox.expose_elixir("puppy", fn p -> to_string(p) <> " is cute" end)
      |> Sandbox.eval_function!("puppy", "dog", 10000)

    assert output == "dog is cute"
  end

  test "can expose Elixir function that reaches reduction limit" do
    state = Sandbox.init()

    long_function = fn ->
      state
      |> Sandbox.expose_elixir("puppy", fn p ->
        Enum.map(1..10000, fn _ -> to_string(p) <> " is cute" end)
        |> List.last()
      end)
      |> Sandbox.eval_function!("puppy", "dog", 2000)
    end

    assert_raise(RuntimeError, "Lua Sandbox exceeded reduction limit!", long_function)
  end

  test "can run a Lua function that updates the Lua state" do
    state = Sandbox.init()

    output =
      state
      |> Sandbox.run_file!("test/lua/bunny.lua")
      |> Sandbox.run_function!("talk", 4, 10000)
      |> Sandbox.get!("talk_count")

    assert output == 4
  end

  test "can inject functionality to state through Elixir" do
    state = Sandbox.init()
    IO.puts("inject")

    output =
      state
      |> Sandbox.inject_elixir("inherit_mobility", &SandboxTest.mobility/1)
      |> Sandbox.eval_file!("test/lua/mobility.lua")
      |> IO.inspect()

    #      |> Sandbox.eval_function!("r", [])
    #      |> Sandbox.eval!("return x")

    #    assert output == "dog is cute"
  end

  #  test "can get value" do
  #    output =
  #      Sandbox.init()
  #      |> Sandbox.set!("some_variable", "some_value")
  #      |> Sandbox.get!("return some_variable")
  #    assert output == "some_value"
  #  end
  #
  #  test "can get value at path" do
  #    output =
  #      Sandbox.init()
  #      |> Sandbox.set!("some_table", [])
  #      |> Sandbox.set!(["some_table", "some_variable"], "some_value")
  #      |> Sandbox.eval!("return some_table.some_variable")
  #    assert output == "some_value"
  #  end

  #
  #  test "bunny can hop" do
  #    output =
  #    Sandbox.init()
  #    |> Sandbox.file_run!("test/lua/bunny.lua")
  #    |> Sandbox.eval!("return move()")
  #    assert output == "hop"
  #  end
end
