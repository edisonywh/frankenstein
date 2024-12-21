defmodule Frankenstein.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # do I need partition supervisor here?
      {PartitionSupervisor, child_spec: Task.Supervisor, name: Frankenstein.LabSupervisor},
      {PartitionSupervisor, child_spec: Task.Supervisor, name: Frankenstein.ExperimentSupervisor}
      # {Task.Supervisor, name: Frankenstein.ExperimentSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Frankenstein.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
