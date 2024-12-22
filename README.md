# Frankenstein

A port of Ruby's `scientist` to help you refactor with confidence.

Meant for: side-effect free code mostly, but you can dependency inject if you'd like.

I want the control to always run, and then the candidate to report in the background.

I need to think about:
- usage, do I expect people to write multiple experiments, like `experiments/pricing_experiment.ex`?
- testing, how can people test it? if they want to raise in test for example, or if they want to silent in test. Do we want people to run it during test?
- do I want to run control first, _then_ experiments?
  - pros is that the experiment has near-zero impact (no added latency)
- maybe I need to introduce Observation?
  - i.e, Result maps {control, observations}
- Frankenstein.Window as in idea? i.e, imagine there is a shared codepath - Frankenstein don't run that bit of code if an experiment is running

# Usage
```elixir

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



