defmodule Frankenstein.Experiment do
  defstruct [:name, :control, :candidate, :context, :options]

  alias Frankenstein.Experiment.Result

  @type t() :: %__MODULE__{
          control: fun(),
          candidate: fun(),
          context: map(),
          options: list()
        }

  # TODO: validate function arity with is_function/2
  # TODO: maybe refactor it to explicitly take in `{module \\ Default, opts}`?
  # def new(module \\ Frankenstein.Experiment.Default, opts) do
  #   control = Keyword.fetch!(opts, :control)
  #   candidate = Keyword.fetch!(opts, :candidate)
  #   context = Keyword.get(opts, :context, %{})

  #   %__MODULE__{
  #     module: module,
  #     control: control,
  #     candidate: candidate,
  #     context: context
  #   }
  # end

  def new(name, opts \\ %{}) do
    default = %{
      control: fn -> :ok end,
      candidate: fn -> :ok end,
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

  def run(name, func) when is_function(func, 0) do
    {time, value} = :timer.tc(func)

    %Result{
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
