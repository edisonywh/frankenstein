defmodule FrankensteinTest do
  use ExUnit.Case, async: true
  doctest Frankenstein

  alias Frankenstein.Experiment

  setup context do
    defmodule DefaultTestExperiment do
      @behaviour Frankenstein.Experiment

      # TODO: change the typespec to return true or false
      def validate(context, {control, candidate}) do
        result =
          if control.value == candidate.value do
            :ok
          else
            :error
          end

        send(context.pid, {:validate, result})

        result
      end

      def publish(event_type, context, results) do
        send(context.pid, {:publish, event_type, results})
        :ok
      end

      def enabled?(context) do
        default = %{enabled: true, pid: nil}

        params = Map.merge(default, context)

        if params.pid do
          send(context.pid, {:enabled?, params.enabled})
        else
          true
        end
      end
    end

    on_exit(fn -> purge(DefaultTestExperiment) end)

    [experiment: DefaultTestExperiment]
  end

  describe "run/1" do
    # test "simple usage works" do
    # experiment =
    # Experiment.new(:test_experiment)
    # |> Experiment.add_control(fn -> 215 + 1 end)
    # |> Experiment.add_candidate(fn -> 217 - 1 end)

    # assert Frankenstein.run(experiment) == 216
    # end

    test "lab works - matches", %{experiment: mod} do
      pid = self()

      experiment =
        Experiment.new(:test_experiment)
        |> Experiment.add_module(mod)
        |> Experiment.add_context(%{pid: pid})
        |> Experiment.add_control(fn -> 215 + 1 end)
        |> Experiment.add_candidate(fn -> 217 - 1 end)

      assert Frankenstein.run(experiment) == 216

      # assert_receive {:validate, _}
      assert_receive {:publish, :match, _}
    end

    test "lab works - mismatches", %{experiment: mod} do
      pid = self()

      experiment =
        Experiment.new(:test_experiment)
        |> Experiment.add_module(mod)
        |> Experiment.add_context(%{pid: pid})
        |> Experiment.add_control(fn -> 215 + 1 end)
        |> Experiment.add_candidate(fn -> 27 - 1 end)

      assert Frankenstein.run(experiment) == 216

      # assert_receive {:validate, _}
      assert_receive {:publish, :mismatch, _}
    end

    # test "validate/1 would yield correct result", %{experiment: experiment} do
    # pid = self()

    # experiment =
    # Experiment.new(:test_experiment)
    # |> Experiment.add_module(experiment)
    # |> Experiment.add_control(fn -> 216 end)
    # |> Experiment.add_candidate(fn -> 216 end)
    # |> Experiment.add_context(%{pid: pid})

    # assert Frankenstein.run(experiment) == 216

    # assert_received {:validate, {%{value: 216}, %{value: 216}}}
    # end

    test "sample/1 would skip", %{experiment: experiment} do
      pid = self()

      experiment =
        Experiment.new(:test_experiment)
        |> Experiment.add_module(experiment)
        |> Experiment.add_control(fn -> 216 end)
        |> Experiment.add_candidate(fn -> flunk("should not be called") end)
        |> Experiment.add_context(%{enabled: false, pid: pid})

      assert Frankenstein.run(experiment) == 216

      assert_received {:enabled?, false}
    end

    test "candidate crashes, should not affect control", %{experiment: experiment} do
      pid = self()

      experiment =
        Experiment.new(:test_experiment)
        |> Experiment.add_module(experiment)
        |> Experiment.add_context(%{pid: pid})
        |> Experiment.add_control(fn -> 216 end)
        |> Experiment.add_candidate(fn -> raise RuntimeError, "candidate raised" end)

      assert Frankenstein.run(experiment) == 216

      assert_receive {:enabled?, true}
      assert_receive {:publish, :exit, {error, _stacktrace}}
      assert error.message =~ ~r/candidate raised/
    end

    test "candidate times out", %{experiment: experiment} do
      pid = self()
      timeout_ms = 50

      experiment =
        Experiment.new(:test_experiment)
        |> Experiment.add_module(experiment)
        |> Experiment.add_context(%{pid: pid})
        |> Experiment.add_control(fn -> 216 end)
        |> Experiment.add_options(timeout: timeout_ms)
        |> Experiment.add_candidate(fn -> Process.sleep(timeout_ms + 1) end)

      assert Frankenstein.run(experiment) == 216

      assert_receive {:enabled?, true}
      assert_receive {:publish, :timeout, _}
    end

    # test "control crashes, should raise" do
    #   experiment =
    #     Experiment.new(:test_experiment)
    #     |> Experiment.add_control(fn -> raise RuntimeError, "candidate raised" end)
    #     |> Experiment.add_candidate(fn -> 216 end)

    #   assert_raise RuntimeError, ~r/candidate raised/, fn ->
    #     Frankenstein.run(experiment)
    #   end
    # end
  end

  defp purge(module) do
    :code.purge(module)
    :code.delete(module)
  end
end
