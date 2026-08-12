# Frankenstein

![logo](./frankenstein.png)

A port of Ruby's `scientist` to help you refactor with confidence.

# Usage
```elixir
experiment = %Frankenstein.Experiment{
  name: :my_experiment,
  control: &original/0,
  candidate: &new/0
  # compare -> defaults to &Kernel.==/2
  # status -> :disabled | :enabled (default) | :adopted, see below
  # timeout -> timeout for the candidate function, raises Frankenstein.TimeoutError
}

Frankenstein.run(experiment)
```

`status` moves an experiment through its lifecycle. The variant whose result is returned always runs in the calling process, so its return value and any exception it raises reach the caller untouched. Only `:enabled` runs both variants; the candidate then runs in a background process, where exceptions are logged rather than raised.

## Adopting an experiment

Set `status: :adopted` to adopt an experiment, making the candidate the live code path and retiring the control. This lets you adopt a variant before cleaning up the experiment code, and lets you write unit tests against both variants when first introducing an experiment.

Frankenstein exposes `:telemetry` instrumentation for you to hook into:
- `[:frankenstein, :experiment, :start]` // `%{experiment_name}`
- `[:frankenstein, :experiment, :stop]` // `%{experiment_name, match}`
- `[:frankenstein, :experiment, :exception]` // `%{experiment_name, kind, reason, stacktrace}`
- `[:frankenstein, :variant, :start]` // `%{experiment_name, variant_name}`
- `[:frankenstein, :variant, :stop]` // `%{experiment_name, variant_name}`
- `[:frankenstein, :variant, :exception]` // `%{experiment_name, variant_name, kind, reason, stacktrace}`

`match` is `true` or `false` when both variants produced a value, and `nil` when they could not be compared.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `frankenstein` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:frankenstein, "~> 0.4.0"}
  ]
end
```
