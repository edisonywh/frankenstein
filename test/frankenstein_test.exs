defmodule FrankensteinTest do
  use ExUnit.Case, async: false

  alias Frankenstein.Experiment

  setup do
    ref =
      :telemetry_test.attach_event_handlers(self(), [
        [:frankenstein, :experiment, :stop],
        [:frankenstein, :test, :stop],
        [:frankenstein, :test, :exception]
      ])

    on_exit(fn -> :telemetry.detach(ref) end)

    :ok
  end

  describe "run/1" do
    test "candidate matches control" do
      experiment = %Experiment{
        name: :my_experiment,
        control: fn -> 215 + 1 end,
        candidate: fn -> 217 - 1 end
      }

      assert Frankenstein.run(experiment) == 216

      assert_receive {[:frankenstein, :test, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        test: :control
                      }}

      assert_receive {[:frankenstein, :test, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        test: :candidate
                      }}

      assert_receive {[:frankenstein, :experiment, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        match: true
                      }}
    end

    test "candidate doesn't match control" do
      experiment = %Experiment{
        name: :my_experiment,
        control: fn -> 215 + 1 end,
        candidate: fn -> 300 end
      }

      assert Frankenstein.run(experiment) == 216

      assert_receive {[:frankenstein, :test, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        test: :control
                      }}

      assert_receive {[:frankenstein, :test, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        test: :candidate
                      }}

      assert_receive {[:frankenstein, :experiment, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        match: false
                      }}
    end

    test "candidate raises an error" do
      experiment = %Experiment{
        name: :my_experiment,
        control: fn -> 215 + 1 end,
        candidate: fn -> raise "borked" end
      }

      assert Frankenstein.run(experiment) == 216

      assert_receive {[:frankenstein, :test, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        test: :control
                      }}

      assert_receive {[:frankenstein, :test, :exception], _, _,
                      %{
                        experiment: :my_experiment,
                        test: :candidate,
                        reason: %RuntimeError{message: "borked"}
                      }}

      assert_receive {[:frankenstein, :experiment, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        match: false
                      }}
    end

    test "control raises an error" do
      experiment = %Experiment{
        name: :my_experiment,
        control: fn -> raise "borked" end,
        candidate: fn -> 432 / 2 end
      }

      assert_raise RuntimeError, fn -> Frankenstein.run(experiment) end

      assert_receive {[:frankenstein, :test, :exception], _, _,
                      %{
                        experiment: :my_experiment,
                        test: :control,
                        reason: %RuntimeError{message: "borked"}
                      }}

      assert_receive {[:frankenstein, :test, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        test: :candidate
                      }}

      assert_receive {[:frankenstein, :experiment, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        match: nil
                      }}
    end

    test "experiment is enabled" do
      pid = self()

      experiment = %Experiment{
        name: :my_experiment,
        control: fn -> 216 end,
        candidate: fn ->
          send(pid, :candidate_called)
          108 * 2
        end,
        enabled?: true
      }

      Frankenstein.run(experiment)

      assert_receive :candidate_called, 1

      assert_receive {[:frankenstein, :test, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        test: :control
                      }}

      assert_receive {[:frankenstein, :test, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        test: :candidate
                      }}

      assert_receive {[:frankenstein, :experiment, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        match: true
                      }}
    end

    test "experiment is disabled" do
      pid = self()

      experiment = %Experiment{
        name: :my_experiment,
        control: fn -> 216 end,
        candidate: fn -> send(pid, :candidate_called) end,
        enabled?: false
      }

      Frankenstein.run(experiment)

      refute_receive :candidate_called, 1

      refute_receive {[:frankenstein, :test, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        test: :control
                      }}

      refute_receive {[:frankenstein, :test, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        test: :candidate
                      }}

      refute_receive {[:frankenstein, :experiment, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        match: true
                      }}
    end

    test "candidate times out" do
      pid = self()

      experiment = %Experiment{
        name: :my_experiment,
        control: fn -> 215 + 1 end,
        candidate: fn ->
          Process.sleep(10)
          send(pid, :candidate_called)
        end,
        timeout: 5
      }

      Frankenstein.run(experiment)

      refute_receive :candidate_called, 20

      assert_receive {[:frankenstein, :test, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        test: :control
                      }}

      assert_receive {[:frankenstein, :test, :exception], _, _,
                      %{
                        experiment: :my_experiment,
                        test: :candidate,
                        reason: %Frankenstein.TimeoutError{timeout_ms: 5}
                      }}

      assert_receive {[:frankenstein, :experiment, :stop], _, _,
                      %{
                        experiment: :my_experiment,
                        match: false
                      }}
    end
  end
end
