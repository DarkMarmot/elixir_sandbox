# Sandbox

Sandbox helps to provide restricted, isolated scripting environments for Elixir through the use of embedded Lua. 
Powered by Robert Virding's amazing Luerl library, its minimal API is focused on facilitating the creation of "safe" server-side DSLs.

The API has been modified from the Erlang original such that functions can modify the state of the VM (mutations) or return a discrete value, but not both.
The `:luerl_sandbox` module is utilized wherever possible.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `sandbox` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sandbox, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/sandbox](https://hexdocs.pm/sandbox).

