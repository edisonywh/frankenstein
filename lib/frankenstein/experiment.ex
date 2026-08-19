defmodule Frankenstein.Experiment do
  @enforce_keys [:name, :control, :candidate]
  defstruct [
    :name,
    :control,
    :candidate,
    compare: &==/2,
    status: :enabled,
    timeout: :infinity
  ]
end
