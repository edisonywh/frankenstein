defmodule FrankensteinTest do
  use ExUnit.Case, async: true
  doctest Frankenstein

  alias Frankenstein.Experiment

  setup context do
    defmodule DefaultTestExperiment do
      @behaviour Frankenstein.Experiment

      def validate(context, results) do
        send(context.pid, {:validate, results})

        :ok
      end

      def publish(event_type, context, results) do
        send(context.pid, {:publish, event_type, results})

        :ok
      end

      def sample(context) do
        if context[:pid] do
          send(context.pid, {:sample, context.enabled})
        else
          true
        end
      end
    end

    on_exit(fn -> purge(DefaultTestExperiment) end)

    [experiment: DefaultTestExperiment]
  end

  describe "run/1" do
    test "simple usage works" do
      experiment =
        Experiment.new(:test_experiment)
        |> Experiment.add_control(fn -> 215 + 1 end)
        |> Experiment.add_candidate(fn -> 217 - 1 end)

      assert Frankenstein.run(experiment) == 216
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

      assert_received {:sample, false}
    end

    test "candidate crashes, should not affect control" do
      experiment =
        Experiment.new(:test_experiment)
        |> Experiment.add_control(fn -> 216 end)
        |> Experiment.add_candidate(fn -> raise RuntimeError, "candidate raised" end)

      assert Frankenstein.run(experiment) == 216
    end
  end

  defp purge(module) do
    :code.purge(module)
    :code.delete(module)
  end
end
