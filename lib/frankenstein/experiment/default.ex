defmodule Frankenstein.Experiment.Default do
  require Logger

  @behaviour Frankenstein.Experiment

  alias Frankenstein.Experiment.Result

  @impl Frankenstein.Experiment
  def sample(_context) do
    # :rand.uniform() > 0.5
    true
  end

  @impl Frankenstein.Experiment
  def validate(_context, {%Result{value: control}, %Result{value: candidate}}) do
    if control == candidate do
      Logger.info("(#{__MODULE__}) match")
    else
      Logger.warning("(#{__MODULE__}) mismatch")
    end
  end

  @impl Frankenstein.Experiment
  # TODO: publish timing results
  def publish(:match, _context, {%Result{}, %Result{}}) do
    # :telemetry.execute([:frankenstein, :experiment, :match], %{
    #     control: control_result,
    #     candidate: candidate_result
    # })
    :ok
  end
end
