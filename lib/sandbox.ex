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
  - Functions starting with `confer` return a new Lua VM state.
  - Functions preceded by `run` return a tuple of `{result, new_state}`
  - All functions return ok-error tuples such as `{:ok, result}` or `{:error, reason}` unless followed by a bang.
  - Elixir functions exposed to Lua return a value indicated by the injecting function (e.g.,
  `set_elixir_to_confer/3` should return a bare Lua VM state).

  """

  @unlimited_reductions 0

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
  Calls a function defined in the the Lua state and returns the result. The state itself is not modified.
  Lua functions can be referenced by a string or list, i.e. `math.floor` or `["math", "floor"]`.
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

  def confer(state, code, max_reductions \\ @unlimited_reductions) do
    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, e} -> {:error, e}
      {_result, new_state} -> {:ok, new_state}
    end
  end

  @doc """
  Same as `confer/3`, but will return the raw result or raise a `RuntimeError`.
  """

  def confer!(state, code, max_reductions \\ @unlimited_reductions) do
    IO.inspect("run: #{inspect(code)} ")

    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, {:reductions, _n}} -> raise("Lua Sandbox exceeded reduction limit!")
      {_result, new_state} -> new_state
    end
  end

  @doc """
  Runs a Lua file in the context of a Lua state and returns a new Lua state.
  """

  def confer_file!(state, file_path, max_reductions \\ @unlimited_reductions) do
    code = File.read!(file_path)
    confer!(state, code, max_reductions)
  end

  @doc """
  Runs a Lua function defined in the given Lua state and returns a new Lua state.
  """

  def confer_function!(state, path, args \\ [], max_reductions \\ @unlimited_reductions)

  def confer_function!(state, path, args, max_reductions) when is_list(path) do
    confer_function!(state, Enum.join(path, "."), args_to_list(args), max_reductions)
  end

  def confer_function!(state, path, args, max_reductions) when is_binary(path) do
    state
    |> set!("__sandbox_args__", args_to_list(args))
    |> confer!("return " <> path <> "(unpack(__sandbox_args__))", max_reductions)
  end

  @spec run(lua_state(), lua_code(), pos_integer()) ::
          {:ok, {lua_result(), lua_state()}} | {:error, any()}
  def run(state, code, max_reductions \\ @unlimited_reductions) do
    case :luerl_sandbox.run(code, state, max_reductions) do
      {:error, e} -> {:error, e}
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
  @spec set_elixir_to_confer!(lua_state(), lua_path(), (lua_state(), [any()] -> lua_state())) ::
          lua_state()
  def set_elixir_to_confer!(state, path, fun) when is_function(fun) do
    value = lua_wrap_elixir_confer(fun)
    set!(state, path, value)
  end

  def set_elixir_to_run!(state, name, fun) when is_function(fun) do
    value = lua_wrap_elixir_run(fun)
    set!(state, name, value)
  end

  # --- private functions ---

  # lua state is unchanged, result returned
  defp lua_wrap_elixir_eval(fun) do
    fn args, state ->
      result = apply(fun, args)
      {[result], state}
    end
  end

  defp lua_wrap_elixir_run(fun) do
    fn args, state ->
      IO.inspect("run args #{inspect(args)}")
      {result, new_state} = apply(fun, [state | args])
      {[result], new_state}
    end
  end

  # lua state is changed
  defp lua_wrap_elixir_confer(fun) do
    fn args, state ->
      IO.inspect("confer args #{inspect(args)}")
      new_state = apply(fun, [state | args])
      #      new_state = fun.(state, args)
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
