defmodule Frankenstein.Experiment.Result do
  defstruct [:lab, :experiment_name, :context, :control, :candidate, :conclusion]

  @type conclusion() ::
          {:ok, :match}
          | {:ok, :mismatch}
          | {:error, :timeout}
          | {:error, term()}

  @type t() :: %__MODULE__{
          lab: module(),
          experiment_name: term(),
          context: map(),
          control: Observation.t(),
          candidate: Observation.t(),
          conclusion: conclusion()
        }
end
