defmodule Frankenstein.Experiment do
  defstruct [:name, :control, :candidate, :context, :options]

  alias Frankenstein.Experiment.Observation
  alias Frankenstein.Experiment.InvalidExperimentSetupError

  @type t() :: %__MODULE__{
          control: fun(),
          candidate: fun(),
          context: map(),
          options: list()
        }

  def new(name, opts \\ %{}) do
    default = %{
      control: fn -> raise InvalidExperimentSetupError, missing_field: :control end,
      candidate: fn -> raise InvalidExperimentSetupError, missing_field: :candidate end,
      context: %{}
    }

    params = Map.merge(default, Enum.into(opts, %{}))

    %__MODULE__{
      name: name,
      control: params.control,
      candidate: params.candidate,
      context: params.context
    }
  end

  @spec run(term(), function()) :: Observation.t()
  def run(name, func) when is_function(func, 0) do
    {time, value} = :timer.tc(func)

    %Observation{
      name: name,
      time_ms: time,
      value: value
    }
  end

  def add_control(%__MODULE__{} = experiment, control) do
    %{experiment | control: control}
  end

  def add_candidate(%__MODULE__{} = experiment, candidate) do
    %{experiment | candidate: candidate}
  end

  def add_context(%__MODULE__{} = experiment, context) do
    %{experiment | context: Enum.into(context, %{})}
  end

  def add_options(%__MODULE__{} = experiment, options) do
    %{experiment | options: Enum.into(options, %{})}
  end
end
