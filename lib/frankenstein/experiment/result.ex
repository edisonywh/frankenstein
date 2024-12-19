defmodule Frankenstein.Experiment.Result do
  defstruct [:time_ms, :vm_stats, :value]

  @type t() :: %__MODULE__{
          time_ms: number(),
          vm_stats: map(),
          value: term()
        }
end
