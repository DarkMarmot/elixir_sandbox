defmodule Sandbox do
  @doc """
  Creates a Lua state with sandbox features.
  """

  def init() do
    :luerl_sandbox.init()
  end

  # todo add chunk and file caching as genserver/registry option

  @doc """
  Evaluates a Lua chunk in the context of the given state. The result is returned whilst the state is unmodified.
  """

  def eval(state, code, max_reductions \\ 1_000_000) do
    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, e} -> {:error, e}
      {result, _new_state} -> {:ok, result}
    end
  end

  @doc """
  Mutates a Lua state by running Lua code against it.
  """

  def run(state, code, max_reductions \\ 1_000_000) do
    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, e} -> {:error, e}
      {_result, new_state} -> {:ok, new_state}
    end
  end

  @doc """
  Sets a value in a Lua state and returns the modified state.
  """

  def set(state, name, value) do
    :luerl.set_table([name], value, state)
  end

  @doc """
  Gets a value from a Lua state.
  """

  def get(state, name) do
    code = "return " <> name
    [result] = run(state, code)
    result
  end

  @doc """
  Exposes a pure Elixir function to the Lua state.
  """

  def expose(state, name, fun) when is_function(fun) do
    value = lua_wrap_pure(fun)
    set(state, name, value)
  end

  @doc """
  Exposes an Elixir function that modifies the current Lua state.
  """

  def inherit(state, name, fun) when is_function(fun) do
    value = lua_wrap_impure(fun)
    set(state, name, value)
  end

  # lua state is unchanged, result returned
  defp lua_wrap_pure(fun) do
    fn args, state ->
      result = apply(fun, args)
      {[result], state}
    end
  end

  # lua state is changed, result suppressed
  defp lua_wrap_impure(fun) do
    fn args, state ->
      new_state = fun.(state, args)
      {[], new_state}
    end
  end
end
