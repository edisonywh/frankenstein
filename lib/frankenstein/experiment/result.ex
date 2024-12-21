defmodule Frankenstein.Experiment.Result do
  defstruct [:name, :time_ms, :vm_stats, :value]

  @type t() :: %__MODULE__{
          name: term(),
          time_ms: number(),
          vm_stats: map(),
          value: term()
        }
end
