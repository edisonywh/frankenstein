defmodule FrankensteinTest do
  use ExUnit.Case, async: true
  doctest Frankenstein

  alias Frankenstein.Experiment

  setup context do
    defmodule TestLab do
      alias Frankenstein.Experiment.Result

      @behaviour Frankenstein.Lab

      # TODO: let people return a Result, or a tuple?
      def refine(%Result{} = result) do
        {result.control.value, result.candidate.value}
      end

      # TODO: change the typespec to return true or false
      def validate(%Result{} = result) do
        result.control.value == result.candidate.value
        # send(context.pid, {:validate, result})
      end

      # def publish(event_type, context, results) do
      #   send(context.pid, {:publish, event_type, results})
      #   :ok
      # end
      def publish(%Result{} = result) do
        # weird API
        event_type =
          case result.conclusion do
            {:ok, :match} -> :match
            {:ok, :mismatch} -> :mismatch
            {:error, :timeout} -> :timeout
            {:error, reason} -> reason
          end

        send(result.context.pid, {:publish, event_type, result})

        :ok
      end

      # def enabled?(_experiment_name, context) do
      def enabled?(%Experiment{} = experiment) do
        default = %{enabled: true, pid: nil}

        params = Map.merge(default, experiment.context)

        if params.pid do
          send(experiment.context.pid, {:enabled?, params.enabled})
        else
          true
        end
      end
    end

    on_exit(fn -> purge(TestLab) end)

    [lab: TestLab]
  end

  describe "run/1" do
    # test "simple usage works" do
    # experiment =
    # Experiment.new(:test_experiment)
    # |> Experiment.add_control(fn -> 215 + 1 end)
    # |> Experiment.add_candidate(fn -> 217 - 1 end)

    # assert Frankenstein.run(experiment) == 216
    # end

    test "lab works - matches", %{lab: lab} do
      pid = self()

      experiment =
        Experiment.new(:test_experiment)
        |> Experiment.add_context(%{pid: pid})
        |> Experiment.add_control(fn -> 215 + 1 end)
        |> Experiment.add_candidate(fn -> 217 - 1 end)

      assert Frankenstein.run(lab, experiment) == 216

      # assert_receive {:validate, _}
      assert_receive {:publish, :match, _}
    end

    test "lab works - mismatches", %{lab: lab} do
      pid = self()

      experiment =
        Experiment.new(:test_experiment)
        |> Experiment.add_context(%{pid: pid})
        |> Experiment.add_control(fn -> 215 + 1 end)
        |> Experiment.add_candidate(fn -> 27 - 1 end)

      assert Frankenstein.run(lab, experiment) == 216

      assert_receive {:enabled?, true}
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

    test "sample/1 would skip", %{lab: lab} do
      pid = self()

      experiment =
        Experiment.new(:test_experiment)
        |> Experiment.add_control(fn -> 216 end)
        |> Experiment.add_candidate(fn -> flunk("should not be called") end)
        |> Experiment.add_context(%{enabled: false, pid: pid})

      assert Frankenstein.run(lab, experiment) == 216

      assert_received {:enabled?, false}
    end

    @tag :skip
    test "candidate crashes, should not affect control", %{lab: lab} do
      pid = self()

      experiment =
        Experiment.new(:test_experiment)
        |> Experiment.add_context(%{pid: pid})
        |> Experiment.add_control(fn -> 216 end)
        |> Experiment.add_candidate(fn -> raise RuntimeError, "candidate raised" end)

      assert Frankenstein.run(lab, experiment) == 216

      assert_receive {:enabled?, true}
      assert_receive {:publish, :exit, {error, _stacktrace}}
      assert error.message =~ ~r/candidate raised/
    end

    test "candidate times out", %{lab: lab} do
      pid = self()
      timeout_ms = 50

      experiment =
        Experiment.new(:test_experiment)
        |> Experiment.add_context(%{pid: pid})
        |> Experiment.add_control(fn -> 216 end)
        |> Experiment.add_options(timeout: timeout_ms)
        |> Experiment.add_candidate(fn -> Process.sleep(timeout_ms + 1) end)

      assert Frankenstein.run(lab, experiment) == 216

      assert_receive {:enabled?, true}
      assert_receive {:publish, :timeout, _}
    end

    test "control crashes, should raise", %{lab: lab} do
      experiment =
        Experiment.new(:test_experiment)
        |> Experiment.add_control(fn -> raise RuntimeError, "control raised" end)
        |> Experiment.add_candidate(fn -> 216 end)

      assert_raise RuntimeError, ~r/control raised/, fn ->
        Frankenstein.run(lab, experiment)
      end
    end

    @tag :skip
    test "refine/2 works" do
      pid = self()

      defmodule RefinedLab do
        def refine(_context, {control, candidate}) do
          refined_candidate = get_in(candidate, [Access.key(:nested), Access.key(:value)])

          {control, refined_candidate}
          |> IO.inspect()
        end

        # I actually want `validate` to validate that the results coming from refine is correctly refined.
        def validate(one, two), do: one == two

        def enabled?(_, _), do: true

        def publish(event_type, context, refined) do
          send(context.pid, {:publish, event_type, refined})
          :ok
        end
      end

      experiment =
        Experiment.new(:test_experiment)
        |> Experiment.add_context(%{pid: pid})
        |> Experiment.add_control(fn -> 216 end)
        |> Experiment.add_candidate(fn -> %{nested: %{value: 216}} end)

      assert Frankenstein.run(RefinedLab, experiment) == 216
      require IEx
      IEx.pry()

      assert_receive {:publish, :match, _}
    end

    # test "we actually spin things up in the background and we do not halt return speed of control"
  end

  defp purge(module) do
    :code.purge(module)
    :code.delete(module)
  end
end
