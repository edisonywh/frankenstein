defmodule Frankenstein do
  @moduledoc """
  Documentation for `Frankenstein`.
  """

  alias Frankenstein.Experiment
  alias Frankenstein.Lab
  alias Frankenstein.Telemetry

  @test_mode Application.compile_env(:frankenstein, :test_mode?, false)

  def run(%Experiment{enabled?: false} = experiment) do
    experiment.control.()
  end

  def run(%Experiment{enabled?: true} = experiment) do
    lab_pid = Lab.start(experiment)

    if @test_mode do
      Process.put(:frankenstein_lab_pid, lab_pid)
    end

    try do
      value = Telemetry.span_test(experiment, :control, experiment.control)
      send(lab_pid, {:control, {:ok, value}})
      value
    rescue
      e ->
        send(lab_pid, {:control, {:error, e}})
        reraise e, __STACKTRACE__
    end
  end
end
