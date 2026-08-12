defmodule FrankensteinTest do
  use ExUnit.Case, async: false

  alias Frankenstein.Experiment

  import ExUnit.CaptureLog

  setup do
    ref =
      :telemetry_test.attach_event_handlers(self(), [
        [:frankenstein, :experiment, :stop],
        [:frankenstein, :variant, :stop],
        [:frankenstein, :variant, :exception]
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

      assert_receive {[:frankenstein, :variant, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
                        variant_name: :control
                      }}

      assert_receive {[:frankenstein, :variant, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
                        variant_name: :candidate
                      }}

      assert_receive {[:frankenstein, :experiment, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
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

      assert_receive {[:frankenstein, :variant, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
                        variant_name: :control
                      }}

      assert_receive {[:frankenstein, :variant, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
                        variant_name: :candidate
                      }}

      assert_receive {[:frankenstein, :experiment, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
                        match: false
                      }}
    end

    test "candidate raises an error" do
      experiment = %Experiment{
        name: :my_experiment,
        control: fn -> 215 + 1 end,
        candidate: fn -> raise "borked" end
      }

      log = capture_log(fn -> run_await(experiment) end)

      assert log =~ "borked"

      assert_receive {[:frankenstein, :variant, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
                        variant_name: :control
                      }}

      assert_receive {[:frankenstein, :variant, :exception], _, _,
                      %{
                        experiment_name: :my_experiment,
                        variant_name: :candidate,
                        reason: %RuntimeError{message: "borked"}
                      }}

      assert_receive {[:frankenstein, :experiment, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
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

      assert_receive {[:frankenstein, :variant, :exception], _, _,
                      %{
                        experiment_name: :my_experiment,
                        variant_name: :control,
                        reason: %RuntimeError{message: "borked"}
                      }}

      assert_receive {[:frankenstein, :variant, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
                        variant_name: :candidate
                      }}

      assert_receive {[:frankenstein, :experiment, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
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
        status: :enabled
      }

      Frankenstein.run(experiment)

      assert_receive :candidate_called, 1

      assert_receive {[:frankenstein, :variant, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
                        variant_name: :control
                      }}

      assert_receive {[:frankenstein, :variant, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
                        variant_name: :candidate
                      }}

      assert_receive {[:frankenstein, :experiment, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
                        match: true
                      }}
    end

    test "experiment is disabled" do
      pid = self()

      experiment = %Experiment{
        name: :my_experiment,
        control: fn -> 216 end,
        candidate: fn -> send(pid, :candidate_called) end,
        status: :disabled
      }

      Frankenstein.run(experiment)

      refute_receive :candidate_called, 1

      refute_receive {[:frankenstein, :variant, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
                        variant_name: :control
                      }}

      refute_receive {[:frankenstein, :variant, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
                        variant_name: :candidate
                      }}

      refute_receive {[:frankenstein, :experiment, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
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

      log = capture_log(fn -> run_await(experiment) end)

      assert log =~ "Test timed out after 5ms"

      refute_receive :candidate_called, 1

      assert_receive {[:frankenstein, :variant, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
                        variant_name: :control
                      }}

      assert_receive {[:frankenstein, :variant, :exception], _, _,
                      %{
                        experiment_name: :my_experiment,
                        variant_name: :candidate,
                        reason: %Frankenstein.TimeoutError{timeout_ms: 5}
                      }}

      assert_receive {[:frankenstein, :experiment, :stop], _, _,
                      %{
                        experiment_name: :my_experiment,
                        match: false
                      }}
    end

    test "experiment is adopted" do
      pid = self()

      experiment = %Experiment{
        name: :my_experiment,
        control: fn -> send(pid, :control_called) end,
        candidate: fn -> 108 * 2 end,
        status: :adopted
      }

      assert Frankenstein.run(experiment) == 216

      refute_receive :control_called, 1

      refute_receive {[:frankenstein, :variant, :stop], _, _, _}, 1
      refute_receive {[:frankenstein, :variant, :exception], _, _, _}, 1
      refute_receive {[:frankenstein, :experiment, :stop], _, _, _}, 1
    end

    test "adopted candidate raises into the caller" do
      experiment = %Experiment{
        name: :my_experiment,
        control: fn -> 216 end,
        candidate: fn -> raise "borked" end,
        status: :adopted
      }

      assert_raise RuntimeError, "borked", fn -> Frankenstein.run(experiment) end

      refute_receive {[:frankenstein, :variant, :exception], _, _, _}, 1
      refute_receive {[:frankenstein, :experiment, :stop], _, _, _}, 1
    end

    test "adopted candidate ignores the timeout" do
      experiment = %Experiment{
        name: :my_experiment,
        control: fn -> 216 end,
        candidate: fn ->
          Process.sleep(10)
          216
        end,
        status: :adopted,
        timeout: 5
      }

      assert Frankenstein.run(experiment) == 216
    end
  end

  defp run_await(experiment) do
    value = Frankenstein.run(experiment)
    lab_pid = Process.get(:frankenstein_lab_pid)
    ref = Process.monitor(lab_pid)

    receive do
      {:DOWN, ^ref, :process, _, _} -> nil
    after
      100 -> raise "Lab.start() timed out after 100ms"
    end

    value
  end
end
