defmodule Frankenstein.Telemetry do
  @telemetry_prefix [:frankenstein]

  def span_experiment(experiment, f) do
    metadata = %{experiment_name: experiment.name}

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

  def span_variant(experiment, variant_name, f) do
    telemetry_metadata = %{experiment_name: experiment.name, variant_name: variant_name}

    :telemetry.span(
      @telemetry_prefix ++ [:variant],
      telemetry_metadata,
      fn ->
        {f.(), telemetry_metadata}
      end
    )
  end
end
