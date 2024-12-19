# Frankenstein

A port of Ruby's `scientist` to help you refactor with confidence.

Meant for: side-effect free code mostly, but you can dependency inject if you'd like.

# Usage
```elixir
mhm,

Frankenstein.run(
  control: &original/1,
  candidate: &new/1
)

Frankenstein.run(%Frankenstein.Experiment{})
```

Frankenstein will run both code paths and always return the old result.

Frankenstein also provides instrumentation hook for you to easily validate your results.

With Elixir, Frankenstein runs your code concurrently.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `frankenstein` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:frankenstein, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/frankenstein>.



