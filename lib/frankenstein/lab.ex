defmodule Frankenstein.Lab do
  alias Frankenstein.Experiment

  # TODO: make plural
  def run(
        %Experiment{
          module: module,
          context: context,
          options: options
        } = experiment,
        %Experiment.Result{} = control
      ) do
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
      Task.yield_many(tasks, options.timeout || 5000)
      |> Enum.map(fn {task, res} -> res || Task.shutdown(task, :brutal_kill) end)

    Enum.map(
      results,
      fn
        nil ->
          module.publish(:timeout, context, nil)

        {:exit, reason} ->
          module.publish(:exit, context, reason)

        {:ok, result} ->
          # todo: refactor to plural, results, maybe {control, [candidate]}
          case module.validate(context, {control, result}) do
            :ok ->
              module.publish(:match, context, {control, result})

            _ ->
              module.publish(:mismatch, context, {control, result})
          end
      end
    )

    :ok
  end
end

# If I want to run one thing async, I need to dynamically start up a lab (genserver) and that genserver will report result
# if I run just tasks, the caller has to await on it, which means I am still missing a process in between.

# Frankenstein.run(experiment)
#   => Frankenstein.Lab # do I need a genserver or a lab?
#     => candidate_1
#     => candidate_2
#     => candidate_3
#     => Task.await(...)
#     => publish/1
