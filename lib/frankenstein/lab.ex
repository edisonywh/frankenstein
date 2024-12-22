defmodule Frankenstein.Lab do
  alias Frankenstein.Experiment

  @type context() :: map()
  @type event_type() :: :match | :mismatch | :skipped

  @callback enabled?(term(), context()) :: boolean()
  @callback validate(context(), {Result.t(), Result.t()}) :: :ok | :mismatch
  @callback publish(event_type(), context(), {Result.t(), Result.t()}) :: :ok | {:error, term()}

  # TODO: make plural
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

    # TODO: remove support for multi candidates
    candidates = List.wrap(experiment.candidate)

    #       Task.Supervisor.async_nolink(
    #         # Frankenstein.ExperimentSupervisor,
    #         # do I need PartitionSupervisor here?
    #         {:via, PartitionSupervisor, {Frankenstein.LabSupervisor, self()}},
    #         # fn -> do_run(candidate_fn) end
    #         # this can be turned into running N candidates
    #         fn -> Lab.run(candidate_fn) end
    #       )

    tasks =
      Enum.map(candidates, fn candidate ->
        # Task.async(fn ->
        # Experiment.run(:candidate, candidate)
        # end)

        Task.Supervisor.async_nolink(
          # {:via, PartitionSupervisor, {Frankenstein.ExperimentSupervisor, self()}},
          {:via, PartitionSupervisor, {Frankenstein.LabSupervisor, self()}},
          fn ->
            Experiment.run(:candidate, candidate)
          end
        )
      end)

    # TODO: configurable timeout
    results =
      Task.yield_many(tasks, opts.timeout)
      |> Enum.map(fn {task, res} -> res || Task.shutdown(task, :brutal_kill) end)

    Enum.map(
      results,
      fn
        nil ->
          lab.publish(:timeout, context, nil)

        {:exit, reason} ->
          lab.publish(:exit, context, reason)

        {:ok, result} ->
          case lab.validate(context, {control, result}) do
            :ok ->
              lab.publish(:match, context, {control, result})

            _ ->
              lab.publish(:mismatch, context, {control, result})
          end
      end
    )

    :ok
  end
end
