defmodule Frankenstein.Lab do
  alias Frankenstein.Experiment

  @type context() :: map()
  @type event_type() :: :match | :mismatch | :skipped

  @callback enabled?(term(), context()) :: boolean()
  @callback validate(context(), {Result.t(), Result.t()}) :: :ok | :mismatch
  @callback publish(event_type(), context(), {Result.t(), Result.t()}) :: :ok | {:error, term()}

  def run(
        lab,
        %Experiment{
          context: context,
          options: options
        } = experiment,
        %Experiment.Result{} = control
      ) do
    opts = %{
      timeout: options[:timeout] || 5000
    }

    task =
      Task.Supervisor.async_nolink(
        {:via, PartitionSupervisor, {Frankenstein.LabSupervisor, self()}},
        fn ->
          Experiment.run(:candidate, experiment.candidate)
        end
      )

    case Task.yield(task, opts.timeout) || Task.shutdown(task) do
      {:ok, result} ->
        case lab.validate(context, {control, result}) do
          :ok ->
            lab.publish(:match, context, {control, result})

          _ ->
            lab.publish(:mismatch, context, {control, result})
        end

      {:exit, reason} ->
        lab.publish(:exit, context, reason)

      nil ->
        lab.publish(:timeout, context, nil)
    end

    :ok
  end
end
