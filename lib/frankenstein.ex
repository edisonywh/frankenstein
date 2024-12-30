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

  def run(
        lab,
        %Experiment{
          control: control
        } = experiment
      ) do
    IO.inspect(control.(), label: "control val")

    observation =
      Experiment.run(:control, control)
      |> tap(fn observation ->
        IO.inspect("starting lab")
        maybe_start_lab(lab, experiment, observation)
        IO.inspect("finished starting lab")
      end)

    IO.inspect(experiment, label: "exp value is")
    IO.inspect(observation, label: "obs value is")

    observation.value
  end

  defp maybe_start_lab(lab, experiment, observation) do
    if lab.enabled?(experiment) do
      IO.inspect("Starting task for lab: #{inspect(self())}")

      Task.Supervisor.start_child(
        Frankenstein.LabSupervisor,
        fn ->
          IO.inspect("Running lab: #{inspect(self())}")
          Frankenstein.Lab.run(lab, experiment, observation)
        end
      )
    end
  end
end
