defmodule Sandbox do
  @moduledoc """
  Sandbox is an Elixir wrapper for Robert Virding's `Luerl`, an Erlang library that lets one execute Lua scripts on the BEAM _without_
  a Lua VM running as a separate application. Sandbox adds additional constraints to `Luerl` and primarily utilizes the
  `:luerl_sandbox` module.

  """

  @default_max_reductions 0

  @type lua_chunk :: {:lua_func, any(), any(), any(), any(), any()}
  @type lua_state ::
          {:luerl, any(), any(), any(), any(), any(), any(), any(), any(), any(), any(), any(),
           any(), any(), any()}
  @type lua_code :: lua_chunk() | String.t()
  @type lua_result :: number() | String.t() | [tuple()]
  @type lua_path :: String.t() | [String.t()]

  @doc """
  Creates a Lua state with sandbox features.
  """
  def init() do
    :luerl_sandbox.init()
  end

  @doc """
  Evaluates a Lua string or chunk against the given Lua state and returns the result in an ok-error tuple. The state itself is not modified.
  """

  @spec eval(lua_state(), lua_code(), pos_integer()) :: {:ok, lua_result()} | {:error, any()}
  def eval(state, code, max_reductions \\ @default_max_reductions) do
    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, e} -> {:error, e}
      {[result], _new_state} -> {:ok, result}
    end
  end

  @doc """
  Same as `eval/3`, but will return the raw result or raise a `RuntimeError`.
  """
  @spec eval!(lua_state(), lua_code(), pos_integer()) :: lua_result()
  def eval!(state, code, max_reductions \\ @default_max_reductions) do
    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, {:reductions, _n}} -> raise("Lua Sandbox exceeded reduction limit!")
      {[result], _new_state} -> result
    end
  end

  @doc """
  Evaluates a Lua file against the given Lua state and returns the result in an ok-error tuple. The state itself is not modified.
  """

  @spec eval_file(lua_state(), String.t(), pos_integer()) :: {:ok, lua_result()} | {:error, any()}
  def eval_file(state, file_path, max_reductions \\ @default_max_reductions) do
    with {:ok, code} <- File.read(file_path),
         {:ok, result} <- eval(state, code, max_reductions) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Same as `eval_file/3`, but will return the raw result or raise a `RuntimeError`.
  """

  @spec eval_file!(lua_state(), String.t(), pos_integer()) :: lua_result()
  def eval_file!(state, file_path, max_reductions \\ @default_max_reductions) do
    code = File.read!(file_path)
    eval!(state, code, max_reductions)
  end

  @doc """
  Calls a function defined in the the Lua state and returns the result. The state itself is not modified.
  Lua functions can be referenced by a string or list, i.e. `math.floor` or `["math", "floor"]`.
  """

  @spec eval_function!(lua_state(), lua_path(), pos_integer()) :: lua_result()
  def eval_function!(state, path, args \\ [], max_reductions \\ @default_max_reductions)

  def eval_function!(state, path, args, max_reductions) when is_list(path) do
    eval_function!(state, Enum.join(path, "."), args_to_list(args), max_reductions)
  end

  def eval_function!(state, path, args, max_reductions) when is_binary(path) do
    state
    |> set!("__sandbox_args__", args_to_list(args))
    |> eval!("return " <> path <> "(unpack(__sandbox_args__))", max_reductions)
  end

  @doc """
  Create a compiled chunk of Lua code that can be transferred between Lua states.
  """
  @spec chunk(lua_state(), lua_code()) :: {:ok, lua_chunk()} | {:error, any()}
  def chunk(state, code) do
    case :luerl.load(code, state) do
      {:ok, result, _state} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec chunk!(lua_state(), lua_code()) :: lua_chunk()
  def chunk!(state, code) do
    {:ok, result} = chunk(state, code)
    result
  end

  @doc """
  Runs a Lua string or chunk against a Lua state and returns a new Lua state in an ok-error tuple.
  """

  def run(state, code, max_reductions \\ 1_000_000) do
    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, e} -> {:error, e}
      {_result, new_state} -> {:ok, new_state}
    end
  end

  @doc """
  Same as `run/3`, but will return the raw result or raise a `RuntimeError`.
  """

  def run!(state, code, max_reductions \\ 1_000_000) do
    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, {:reductions, _n}} -> raise("Lua Sandbox exceeded reduction limit!")
      {_result, new_state} -> new_state
    end
  end

  @doc """
  Runs a Lua file in the context of a Lua state and returns a new Lua state.
  """

  def run_file!(state, file_path, max_reductions \\ @default_max_reductions) do
    code = File.read!(file_path)
    run!(state, code, max_reductions)
  end

  @doc """
  Runs a Lua function defined in the given Lua state and returns a new Lua state.
  """

  def run_function!(state, path, args \\ [], max_reductions \\ @default_max_reductions)

  def run_function!(state, path, args, max_reductions) when is_list(path) do
    run_function!(state, Enum.join(path, "."), args_to_list(args), max_reductions)
  end

  def run_function!(state, path, args, max_reductions) when is_binary(path) do
    state
    |> set!("__sandbox_args__", args_to_list(args))
    |> run!(path <> "(unpack(__sandbox_args__))", max_reductions)
  end

  @doc """
  Sets a value in a Lua state and returns the modified state.
  """
  # add options, force: true to create missing tables?

  def set!(state, path, value, force \\ false)

  def set!(state, path, value, force) when is_binary(path) do
    set!(state, String.split(path, "."), value, force)
  end

  def set!(state, path, value, false) when is_list(path) do
    :luerl.set_table(path, value, state)
  end

  def set!(state, path, value, true) when is_list(path) do
    :luerl.set_table(path, value, state)
  end

  @doc """
  Gets a value from a Lua state.
  """

  def get!(state, path) when is_list(path) do
    code = "return " <> Enum.join(path, ".")
    eval!(state, code)
  end

  def get!(state, path) when is_binary(path) do
    code = "return " <> path
    eval!(state, code)
  end

  @doc """
  Exposes an Elixir function for use within the Lua state. This function cannot modify the state of the Lua VM; it can
  only return a value.
  """

  def expose_elixir(state, name, fun) when is_function(fun) do
    value = lua_wrap_pure(fun)
    set!(state, name, value)
  end

  @doc """
  Injects an Elixir function that can mutate the Lua state containing.
  This is primarily for letting Lua scripts use something like inheritance, dynamically adding external functionality and settings.
  The given function should accept, modify and return a Lua state.
  """

  def inject_elixir(state, name, fun) when is_function(fun) do
    value = lua_wrap_impure(fun)
    set!(state, name, value)
  end

  # --- private functions ---

  # lua state is unchanged, result returned
  defp lua_wrap_pure(fun) do
    fn args, state ->
      result = apply(fun, args)
      {[result], state}
    end
  end

  # lua state is changed, result suppressed
  defp lua_wrap_impure(fun) do
    fn _args, state ->
      new_state = fun.(state)
      {[], new_state}
    end
  end

  defp args_to_list(args) when is_list(args) do
    args
  end

  defp args_to_list(args) do
    [args]
  end
end
