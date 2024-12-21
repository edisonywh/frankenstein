defmodule Frankenstein.Experiment do
  defstruct [:name, :module, :control, :candidate, :context]

  alias Frankenstein.Experiment.Result

  @type t() :: %__MODULE__{
          module: module(),
          control: fun(),
          candidate: fun(),
          context: map()
        }

  @type context() :: map()
  @type event_type() :: :match | :mismatch | :skipped

  @callback enabled?(context()) :: boolean()
  @callback validate(context(), {Result.t(), Result.t()}) :: :ok | :mismatch
  @callback publish(event_type(), context(), {Result.t(), Result.t()}) :: :ok | {:error, term()}

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
      module: Frankenstein.Experiment.Default,
      control: fn -> :ok end,
      candidate: fn -> :ok end,
      context: %{}
    }

    params = Map.merge(default, Enum.into(opts, %{}))

    %__MODULE__{
      name: name,
      module: params.module,
      control: params.control,
      candidate: params.candidate,
      context: params.context
    }
  end

  def add_module(%__MODULE__{} = experiment, module) do
    %{experiment | module: module}
  end

  def add_control(%__MODULE__{} = experiment, control) do
    %{experiment | control: control}
  end

  def add_candidate(%__MODULE__{} = experiment, candidate) do
    %{experiment | candidate: candidate}
  end

  def add_context(%__MODULE__{} = experiment, context) do
    %{experiment | context: context}
  end
end
