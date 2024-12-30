defmodule Frankenstein.Experiment.InvalidExperimentSetupError do
  defexception [:message, :missing_field]

  def exception(opts) do
    missing_field = Keyword.fetch!(opts, :missing_field)

    message =
      case missing_field do
        :control -> "control not provided"
        :candidate -> "candidate not provided"
      end

    %__MODULE__{message: message}
  end
end
