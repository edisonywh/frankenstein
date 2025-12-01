# Frankenstein

A port of Ruby's `scientist` to help you refactor with confidence.

# Usage
```elixir
experiment = %Frankenstein.Experiment{
  name: :my_experiment,
  control: &original/0,
  candidate: &new/0
  # compare -> defaults to &Kernel.==/2
  # enabled? -> boolean for you to control if candidate should run
  # timeout -> timeout for the candidate function, raises Frankenstein.TimeoutError
}

Frankenstein.run(experiment)
```

Frankenstein always returns the control result, if `enabled?` is evaluated to true, Frankenstein runs the candidate in a separate process concurrently and results are reported with telemetry.

Frankenstein exposes `:telemetry` instrumentation for you to hook into:
- `[:frankenstein, :experiment, :start]` // `%{experiment, match?}`
- `[:frankenstein, :experiment, :stop]` // `%{experiment, match?}`
- `[:frankenstein, :test, :start]` // `%{experiment, test}`
- `[:frankenstein, :test, :stop]` // `%{experiment, test}`

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
