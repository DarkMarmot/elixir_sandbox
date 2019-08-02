defmodule Sandbox do
  @moduledoc """

  Sandbox provides restricted, isolated scripting environments for Elixir through the use of embedded Lua.

  This project is powered by Robert Virding's amazing [Luerl](https://github.com/rvirding/luerl), an Erlang library that lets one execute Lua scripts on the BEAM.
  Luerl executes Lua code _without_ running a Lua VM as a separate application! Rather, the state of the VM is used as a
  data structure that can be externally manipulated and processed.

  The `:luerl_sandbox` module is utilized wherever possible. This limits access to dangerous core libraries.
  It also permits Lua scripts to be run with enforced CPU reduction limits. To work with Lua's full library, use
  `Sandbox.unsafe_init/0` as opposed to `Sandbox.init/0`.

  Conventions followed in this library:

  - Functions beginning with `eval` return a Lua result.
  - Functions starting with `play` return a new Lua VM state.
  - Functions preceded by `run` return a tuple of `{result, new_state}`
  - All functions return ok-error tuples such as `{:ok, result}` or `{:error, reason}` unless followed by a bang.
  - Elixir functions exposed to Lua should all take two arguments: a Lua state and a list of Lua arguments. They
    should return a value corresponding to the `eval`, `play` or `run` responses.

  """

  @unlimited_reductions 0

  @type lua_chunk :: {:lua_func, any(), any(), any(), any(), any()}
  @type lua_state ::
          {:luerl, any(), any(), any(), any(), any(), any(), any(), any(), any(), any(), any(),
           any(), any(), any()}
  @type lua_code :: lua_chunk() | String.t()
  @type lua_result :: number() | String.t() | [tuple()]
  @type lua_path :: String.t() | [String.t()]
  @type elixir_run_fun :: (lua_state(), [any()] -> {lua_result(), lua_state()})
  @type elixir_eval_fun :: (lua_state(), [any()] -> lua_result())
  @type elixir_play_fun :: (lua_state(), [any()] -> lua_state())

  @doc """
  Creates a Lua state with sandbox features.
  """
  def init() do
    :luerl_sandbox.init()
  end

  def unsafe_init() do
    :luerl.init()
  end

  @doc """
  Evaluates a Lua string or chunk against the given Lua state and returns the result in an ok-error tuple. The state itself is not modified.
  """

  @spec eval(lua_state(), lua_code(), pos_integer()) :: {:ok, lua_result()} | {:error, any()}
  def eval(state, code, max_reductions \\ @unlimited_reductions) do
    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, e} -> {:error, e}
      {[result], _new_state} -> {:ok, result}
    end
  end

  @doc """
  Same as `eval/3`, but will return the raw result or raise a `RuntimeError`.
  """
  @spec eval!(lua_state(), lua_code(), pos_integer()) :: lua_result()
  def eval!(state, code, max_reductions \\ @unlimited_reductions) do
    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, {:reductions, _n}} -> raise("Lua Sandbox exceeded reduction limit!")
      {:error, reason} -> raise("Lua Sandbox: #{inspect(reason)}")
      {[result], _new_state} -> result
    end
  end

  @doc """
  Evaluates a Lua file against the given Lua state and returns the result in an ok-error tuple. The state itself is not modified.
  """

  @spec eval_file(lua_state(), String.t(), pos_integer()) :: {:ok, lua_result()} | {:error, any()}
  def eval_file(state, file_path, max_reductions \\ @unlimited_reductions) do
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
  def eval_file!(state, file_path, max_reductions \\ @unlimited_reductions) do
    code = File.read!(file_path)
    eval!(state, code, max_reductions)
  end

  @doc """
  Calls a function defined in the the Lua state and returns only the result. The state itself is not modified.
  Lua functions in the Lua state can be referenced by their `lua_path`, being a string or list such as `math.floor` or `["math", "floor"]`.
  """

  @spec eval_function!(lua_state(), lua_path(), pos_integer()) :: lua_result()
  def eval_function!(state, path, args \\ [], max_reductions \\ @unlimited_reductions)

  def eval_function!(state, path, args, max_reductions) when is_list(path) do
    eval_function!(state, Enum.join(path, "."), args_to_list(args), max_reductions)
  end

  def eval_function!(state, path, args, max_reductions) when is_binary(path) do
    state
    |> set!("__sandbox_args__", args_to_list(args))
    |> eval!("return " <> path <> "(unpack(__sandbox_args__))", max_reductions)
  end

  @doc """
  Create a compiled chunk of Lua code that can be transferred between Lua states, returned in an ok-error tuple.
  """
  @spec chunk(lua_state(), lua_code()) :: {:ok, lua_chunk()} | {:error, any()}
  def chunk(state, code) do
    case :luerl.load(code, state) do
      {:ok, result, _state} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Same as `chunk/2`, but will return the raw result or raise a `RuntimeError`.
  """

  @spec chunk!(lua_state(), lua_code()) :: lua_chunk()
  def chunk!(state, code) do
    {:ok, result} = chunk(state, code)
    result
  end

  @doc """
  Runs a Lua string or chunk against a Lua state and returns a new Lua state in an ok-error tuple.
  """

  def play(state, code, max_reductions \\ @unlimited_reductions) do
    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, e} -> {:error, e}
      {_result, new_state} -> {:ok, new_state}
    end
  end

  @doc """
  Same as `play/3`, but will return the raw result or raise a `RuntimeError`.
  """

  def play!(state, code, max_reductions \\ @unlimited_reductions) do
    IO.inspect("run: #{inspect(code)} ")

    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, {:reductions, _n}} -> raise("Lua Sandbox exceeded reduction limit!")
      {_result, new_state} -> new_state
    end
  end

  @doc """
  Runs a Lua file in the context of a Lua state and returns a new Lua state.
  """

  def play_file!(state, file_path, max_reductions \\ @unlimited_reductions) do
    code = File.read!(file_path)
    play!(state, code, max_reductions)
  end

  @doc """
  Runs a Lua function defined in the given Lua state and returns a new Lua state.
  """

  def play_function!(state, path, args \\ [], max_reductions \\ @unlimited_reductions)

  def play_function!(state, path, args, max_reductions) when is_list(path) do
    play_function!(state, Enum.join(path, "."), args_to_list(args), max_reductions)
  end

  def play_function!(state, path, args, max_reductions) when is_binary(path) do
    state
    |> set!("__sandbox_args__", args_to_list(args))
    |> play!("return " <> path <> "(unpack(__sandbox_args__))", max_reductions)
  end

  @doc """
  Runs a Lua string or chunk against the given Lua state and returns the result and the new Lua state in an ok-error tuple.
  """

  @spec run(lua_state(), lua_code(), pos_integer()) ::
          {:ok, lua_state() | {lua_result(), lua_state()}} | {:error, any()}
  def run(state, code, max_reductions \\ @unlimited_reductions) do
    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, e} -> {:error, e}
      {[], new_state} -> {:ok, {nil, new_state}}
      {[result], new_state} -> {:ok, {result, new_state}}
    end
  end

  @doc """
  Same as `run/3`, but will return the raw `{result, state}` or raise a `RuntimeError`.
  """
  @spec run!(lua_state(), lua_code(), pos_integer()) :: lua_result()
  def run!(state, code, max_reductions \\ @unlimited_reductions) do
    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, {:reductions, _n}} -> raise("Lua Sandbox exceeded reduction limit!")
      {[result], new_state} -> {result, new_state}
    end
  end

  @doc """
  Runs a function defined in the the Lua state and returns the result and the new Lua state as `{result, state}`.
  Lua functions in the Lua state can be referenced by their `lua_path`, a string or list such as `math.floor` or `["math", "floor"]`.
  """

  @spec run_function!(lua_state(), lua_path(), pos_integer()) :: lua_result()
  def run_function!(state, path, args \\ [], max_reductions \\ @unlimited_reductions)

  def run_function!(state, path, args, max_reductions) when is_list(path) do
    run_function!(state, Enum.join(path, "."), args_to_list(args), max_reductions)
  end

  def run_function!(state, path, args, max_reductions) when is_binary(path) do
    state
    |> set!("__sandbox_args__", args_to_list(args))
    |> run!("return " <> path <> "(unpack(__sandbox_args__))", max_reductions)
  end

  @doc """
  Sets a value in a Lua state and returns the modified state. If `force` is set to true, new tables will be created
  automatically if they missing from the given `lua_path`.
  """

  def set!(state, path, value, force \\ false)

  def set!(state, path, value, force) when is_binary(path) do
    set!(state, String.split(path, "."), value, force)
  end

  def set!(state, path, value, false) when is_list(path) do
    :luerl.set_table(path, value, state)
  end

  def set!(state, path, value, true) when is_list(path) do
    :luerl.set_table(path, value, build_missing_tables(state, path))
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
  @spec set_elixir_to_eval!(lua_state(), lua_path(), elixir_eval_fun()) ::
          lua_state()
  def set_elixir_to_eval!(state, name, fun) when is_function(fun) do
    value = lua_wrap_elixir_eval(fun)
    set!(state, name, value)
  end

  @doc """
  Exposes an Elixir function that can modify the Lua state of the script calling it.
  This is primarily for letting Lua scripts use something like inheritance, dynamically adding external functionality and settings.

  The given Elixir function will receive two arguments, a Lua state and a list containing any arguments from Lua. It should return
  a new Lua VM state.

  This function will return a new Lua state with access to the Elixir function at the given table path.
  """
  @spec set_elixir_to_play!(lua_state(), lua_path(), elixir_play_fun()) ::
          lua_state()
  def set_elixir_to_play!(state, path, fun) when is_function(fun) do
    value = lua_wrap_elixir_play(fun)
    set!(state, path, value)
  end

  @spec set_elixir_to_run!(lua_state(), lua_path(), elixir_run_fun()) ::
          lua_state()
  def set_elixir_to_run!(state, name, fun) when is_function(fun) do
    value = lua_wrap_elixir_run(fun)
    set!(state, name, value)
  end

  # --- private functions ---

  # lua state is unchanged, result returned
  defp lua_wrap_elixir_eval(fun) do
    fn args, state ->
      result = fun.(state, args)
      {[result], state}
    end
  end

  defp lua_wrap_elixir_run(fun) do
    fn args, state ->
#      IO.inspect("run args #{inspect(args)}")
                                            {result, new_state} = fun.(state, args)
#      {result, new_state} = apply(fun, [state | args])
      {[result], new_state}
    end
  end

  # lua state is changed
  defp lua_wrap_elixir_play(fun) do
    fn args, state ->
      new_state = fun.(state, args)
      {[], new_state}
    end
  end

  defp args_to_list(args) when is_list(args) do
    args
  end

  defp args_to_list(args) do
    [args]
  end

  defp build_missing_tables(state, path, path_string \\ nil)

  defp build_missing_tables(state, [], _path_string) do
    state
  end

  defp build_missing_tables(state, [name | path_remaining], path_string) do
    next_path_string =
      case path_string do
        nil -> name
        _ -> path_string <> "." <> name
      end

    next_state =
      case get!(state, next_path_string) do
        nil -> set!(state, next_path_string, [])
        _ -> state
      end

    build_missing_tables(next_state, path_remaining, next_path_string)
  end
end
