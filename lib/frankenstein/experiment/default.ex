# defmodule Frankenstein.Experiment.Default do
#   require Logger

#   @behaviour Frankenstein.Lab

#   alias Frankenstein.Experiment.Result

#   @impl Frankenstein.Lab
#   def enabled?(_experiment_name, _context) do
#     # :rand.uniform() > 0.5
#     true
#   end

#   @impl Frankenstein.Lab
#   def validate(_context, {%Result{value: control}, %Result{value: candidate}}) do
#     if control == candidate do
#       Logger.info("(#{__MODULE__}) match")
#     else
#       Logger.warning("(#{__MODULE__}) mismatch")
#     end
#   end

#   @impl Frankenstein.Lab
#   # TODO: publish timing results
#   def publish(:match, _context, {%Result{}, %Result{}}) do
#     # :telemetry.execute([:frankenstein, :experiment, :match], %{
#     #     control: control_result,
#     #     candidate: candidate_result
#     # })
#     :ok
#   end
# end
