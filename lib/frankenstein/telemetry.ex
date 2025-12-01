defmodule Frankenstein.Telemetry do
  @telemetry_prefix [:frankenstein]

  def span_experiment(experiment, f) do
    metadata = %{experiment: experiment.name}

    :telemetry.span(
      @telemetry_prefix ++ [:experiment],
      metadata,
      fn ->
        match? = f.()
        metadata = Map.put(metadata, :match, match?)
        {match?, metadata}
      end
    )
  end

  def span_test(experiment, test_name, f) do
    telemetry_metadata = %{experiment: experiment.name, test: test_name}

    :telemetry.span(
      @telemetry_prefix ++ [:test],
      telemetry_metadata,
      fn ->
        {f.(), telemetry_metadata}
      end
    )
  end
end
