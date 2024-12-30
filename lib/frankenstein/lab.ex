defmodule Frankenstein.Lab do
  alias Frankenstein.Experiment
  alias Frankenstein.Experiment.Result

  @type context() :: map()
  @type event_type() :: :match | :mismatch | :skipped
  @type refined_control_value() :: term()
  @type refined_candidate_value() :: term()

  # @callback enabled?(term(), context()) :: boolean()
  # @callback validate(context(), {Result.t(), Result.t()}) :: boolean()
  # @callback publish(event_type(), context(), {Result.t(), Result.t()}) :: :ok | {:error, term()}

  # @callback enabled?(term(), context()) :: boolean()
  # done
  @callback enabled?(Experiment.t()) :: boolean()
  @callback refine(Result.t()) ::
              {refined_control_value(), refined_candidate_value()}
  # done (?)
  @callback validate(Result.t()) :: boolean()
  # ?
  @callback publish(Result.t()) :: :ok | {:error, term()}

  def run(
        lab,
        %Experiment{
          context: context,
          options: options
        } = experiment,
        %Experiment.Observation{} = obvs_control
      ) do
    opts = %{
      timeout: options[:timeout] || 5000
    }

    task =
      Task.Supervisor.async_nolink(
        # {:via, PartitionSupervisor, {Frankenstein.LabSupervisor, self()}},
        Frankenstein.ExperimentSupervisor,
        fn ->
          IO.inspect("Running experiment: #{inspect(self())}")
          Process.sleep(3000)
          Experiment.run(:candidate, experiment.candidate)
        end
      )

    result = %Experiment.Result{
      lab: lab,
      context: context,
      experiment_name: experiment.name,
      control: obvs_control
    }

    case Task.yield(task, opts.timeout) || Task.shutdown(task) do
      {:ok, obvs_candidate} ->
        result = Map.put(result, :candidate, obvs_candidate)

        result
        |> lab.refine()
        |> case do
          {refined_control, refined_candidate} ->
            result
            |> Map.put(:control, Map.put(result.control, :value, refined_control))
            |> Map.put(:candidate, Map.put(result.candidate, :value, refined_candidate))
        end
        |> then(fn result ->
          if lab.validate(result) do
            %{result | conclusion: {:ok, :match}}
          else
            %{result | conclusion: {:ok, :mismatch}}
          end
        end)
        |> lab.publish()

      {:exit, reason} ->
        # TODO: maybe I want to also match error with control, but I don't support case when control crashes (mhm)
        result = %{result | conclusion: {:error, reason}}
        IO.inspect(result, label: "result is")
        # Q: should I call lab.publish, or use :telemetry? If I do telemetry, the logic for people to
        # publish data would likely live elsewhere, which might not be super cool.
        # the set-up is also slightly more cumbersome no?
        # but it would be good because it'd be visible to people
        lab.publish(result)

      nil ->
        result = %{result | conclusion: {:error, :timeout}}
        lab.publish(result)
    end

    :dafuq
  end
end
