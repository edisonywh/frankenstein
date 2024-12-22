defmodule Frankenstein do
  @moduledoc """
  Documentation for `Frankenstein`.

  Frankenstein allows you to test in production with confidence.

  Frankenstein runs your candidate(s) in the background and report back the result.

  ## Process architecture
  Each successful invocation of an experiment creates a new LabSupervisor, and these LabSupervisor supervises your candidate(s)

  The LabSupervisor ensures that:
  - errors from candidates do not impact your system
  - results from candidates are published
  """

  require Logger

  alias Frankenstein.Experiment
  # alias Frankenstein.Experiment.Result

  def run(
        lab,
        %Experiment{
          context: context,
          control: control
        } = experiment
      ) do
    result = Experiment.run(:control, control)

    if lab.enabled?(experiment.name, context) do
      Task.Supervisor.start_child(
        {:via, PartitionSupervisor, {Frankenstein.LabSupervisor, self()}},
        fn ->
          # it's a bit weird passing both experiments in here
          Frankenstein.Lab.run(lab, experiment, result)
        end
      )
    end

    result.value
  end

  # mhm vm snapshot before and after doesn't make sense because they run concurrently
  # def run(%Experiment{
  #       module: module,
  #       control: control_fn,
  #       candidate: candidate_fn,

  #       context: context
  #     }) do
  #   tasks = [
  #     # Task.completed(do_run(control_fn)),
  #     Task.async(fn -> do_run(control_fn) end),
  #     if module.enabled?(context) do
  #       Task.Supervisor.async_nolink(
  #         # Frankenstein.ExperimentSupervisor,
  #         # do I need PartitionSupervisor here?
  #         {:via, PartitionSupervisor, {Frankenstein.LabSupervisor, self()}},
  #         # fn -> do_run(candidate_fn) end
  #         # this can be turned into running N candidates
  #         fn -> Lab.run(candidate_fn) end
  #       )
  #     else
  #       # is this even a good idea?
  #       Task.completed(:skipped)
  #     end
  #   ]

  #   # TODO: I want to await infinity for control, and customizable timeout for candidate
  #   # TODO: decide to run experiment or not based on Behaviour.sample/0
  #   tasks
  #   |> Task.yield_many()
  #   |> Enum.map(fn {task, res} ->
  #     res || Task.shutdown(task)
  #   end)
  #   |> case do
  #     [{:ok, control_result}, {:ok, %Result{value: :skipped}}] ->
  #       control_result.value

  #     [{:ok, control_result}, {:ok, candidate_result}] ->
  #       # module.validate({control_result, candidate_result})
  #       # module.publish(:match, {control_result, candidate_result})

  #       {control_result, candidate_result}
  #       |> tap(&module.validate(context, &1))
  #       |> then(&module.publish(:match, context, &1))

  #       control_result.value

  #     # TODO: render error nicely // move to behaviour
  #     [{:ok, result}, {:exit, {error, stacktrace}}] ->
  #       Logger.warning(
  #         "Candidate failed with error (#{error.__struct__}) #{inspect(error.message)}"
  #       )

  #       result.value

  #     # TODO: move to behaviour (?)
  #     [{:ok, result}, nil] ->
  #       # module.handle_timeout(context), module.publish(:timeout)
  #       Logger.warning("Candidate timed out")

  #       result
  #   end
  # end

  # defp do_run(func) do
  #   {time, value} = :timer.tc(func)

  #   %Result{
  #     time_ms: time,
  #     value: value
  #   }
  # end
end
