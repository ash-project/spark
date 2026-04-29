# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Dsl.TestCollectorTest do
  @moduledoc """
  Tests for the test-collector hook in `Spark.Dsl.__verify_spark_dsl__/1`.

  When a process has registered itself as a verifier-error collector via
  `Process.put({Spark.Dsl, :test_collector}, pid)`, verifier errors that
  would otherwise be raised (and converted to stderr warnings by the
  `@after_verify` catch block) are instead routed via
  `send(pid, {Spark.Dsl, :verifier_errors, module, errors})` and the
  post-error `run_transformers` call is skipped.

  Default behavior (flag unset, or set to a non-pid value) is preserved.

  ## Test convention

  Every `defmodule` defined inside an anonymous function (e.g. inside a
  `capture_io/2` callback or `Task.async/1` body) uses the explicit
  `Elixir.SomeName` form. Inside such an anonymous function, a bare alias
  in a `defmodule` head is resolved against the surrounding test module
  scope, so `defmodule SomeName` would create `Spark.Dsl.TestCollectorTest.SomeName`.
  Outside the function (where `assert_received` patterns live), the bare alias
  `SomeName` resolves to top-level `Elixir.SomeName` — a different atom — and
  the pattern would never match. Forcing top-level resolution at the defmodule
  site keeps both sides aligned.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  setup do
    debug_info? = Code.get_compiler_option(:debug_info)
    Code.put_compiler_option(:debug_info, true)
    on_exit(fn -> Code.put_compiler_option(:debug_info, debug_info?) end)
    :ok
  end

  describe "default path (no collector flag)" do
    test "single verifier error is rendered as a stderr warning" do
      # Defensive: ensure no flag leaked into this process.
      Process.delete({Spark.Dsl, :test_collector})

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.DefaultPathGandalf do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end)

      assert stderr =~ "Cannot be gandalf"
      refute_received {Spark.Dsl, :verifier_errors, _, _}
    end

    test "non-pid collector value falls through to default warn path" do
      # Setting a non-pid value must not enter the collector branch.
      # No cleanup needed: with async: true the test process exits and its
      # process dict is reclaimed automatically.
      Process.put({Spark.Dsl, :test_collector}, :not_a_pid)

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.NonPidFlagGandalf do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end)

      assert stderr =~ "Cannot be gandalf"
      refute_received {Spark.Dsl, :verifier_errors, _, _}
    end

    test "multiple errors from one module render the multi-error envelope" do
      Process.delete({Spark.Dsl, :test_collector})

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.DefaultPathMultiError do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end

            presets do
              preset(:foo)
              preset(:foo)
            end
          end
        end)

      assert stderr =~ "Multiple Errors Occurred"
      assert stderr =~ "Cannot be gandalf"
      assert stderr =~ "Got duplicate"
      refute_received {Spark.Dsl, :verifier_errors, _, _}
    end
  end

  describe "collector branch (flag set to live pid)" do
    test "single verifier error is routed via send and no warning is emitted" do
      Process.put({Spark.Dsl, :test_collector}, self())

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.CollectedGandalf do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end)

      assert stderr == ""

      assert_received {Spark.Dsl, :verifier_errors, CollectedGandalf, errors}
      assert [%Spark.Error.DslError{} = err] = errors
      assert err.message =~ "Cannot be gandalf"
      assert err.path == [:personal_details, :first_name]
    end

    test "valid module with flag set sends no message and no warning" do
      Process.put({Spark.Dsl, :test_collector}, self())

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.CollectedValid do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Zach")
            end
          end
        end)

      assert stderr == ""
      refute_received {Spark.Dsl, :verifier_errors, _, _}
    end

    test "multiple errors from one module are delivered in a single message" do
      Process.put({Spark.Dsl, :test_collector}, self())

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.CollectedMultiError do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end

            presets do
              preset(:foo)
              preset(:foo)
            end
          end
        end)

      assert stderr == ""

      assert_received {Spark.Dsl, :verifier_errors, CollectedMultiError, errors}
      assert length(errors) == 2

      assert Enum.any?(errors, fn err ->
               is_struct(err, Spark.Error.DslError) and err.message =~ "Cannot be gandalf"
             end)

      assert Enum.any?(errors, fn err ->
               is_struct(err, Spark.Error.DslError) and err.message =~ "Got duplicate"
             end)

      refute_received {Spark.Dsl, :verifier_errors, _, _}
    end

    test "each defined module emits its own message in definition order" do
      Process.put({Spark.Dsl, :test_collector}, self())

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.CollectedSequenceFirst do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end

          defmodule Elixir.CollectedSequenceSecond do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end

          defmodule Elixir.CollectedSequenceValid do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Zach")
            end
          end
        end)

      assert stderr == ""

      assert_received {Spark.Dsl, :verifier_errors, CollectedSequenceFirst, [_]}
      assert_received {Spark.Dsl, :verifier_errors, CollectedSequenceSecond, [_]}
      refute_received {Spark.Dsl, :verifier_errors, _, _}
    end

    test "flag pointing at a dead pid does not crash and emits no warning" do
      dead = spawn(fn -> :ok end)
      ref = Process.monitor(dead)
      assert_receive {:DOWN, ^ref, :process, ^dead, _}, 200

      Process.put({Spark.Dsl, :test_collector}, dead)

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.CollectedDeadPidGandalf do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end)

      assert stderr == ""
      refute_received {Spark.Dsl, :verifier_errors, _, _}
    end

    test "flag pointing at another live process delivers messages to that process" do
      parent = self()

      child =
        spawn_link(fn ->
          receive do
            {Spark.Dsl, :verifier_errors, _mod, _errs} = msg ->
              send(parent, {:forwarded, msg})
          after
            500 -> send(parent, :timeout)
          end
        end)

      Process.put({Spark.Dsl, :test_collector}, child)

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.CollectedRemoteGandalf do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end)

      assert stderr == ""

      assert_receive {:forwarded,
                      {Spark.Dsl, :verifier_errors, CollectedRemoteGandalf,
                       [%Spark.Error.DslError{}]}},
                     500
    end

    test "flag is re-read on every defmodule, not cached" do
      Process.put({Spark.Dsl, :test_collector}, self())

      stderr_collected =
        capture_io(:stderr, fn ->
          defmodule Elixir.CollectedFreshFirst do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end)

      assert stderr_collected == ""
      assert_received {Spark.Dsl, :verifier_errors, CollectedFreshFirst, [_]}

      Process.delete({Spark.Dsl, :test_collector})

      stderr_default =
        capture_io(:stderr, fn ->
          defmodule Elixir.CollectedFreshSecond do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end)

      assert stderr_default =~ "Cannot be gandalf"
      refute_received {Spark.Dsl, :verifier_errors, _, _}
    end

    test "after-compile transformers do NOT run when errors are collected" do
      counter_key = {Spark.Test.CollectorFixture, :counter}
      Process.put(counter_key, 0)
      Process.put({Spark.Dsl, :test_collector}, self())

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.CollectedTransformerSkipped do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_error(true)
            end
          end
        end)

      assert stderr == ""

      assert_received {Spark.Dsl, :verifier_errors, CollectedTransformerSkipped,
                       [%Spark.Error.DslError{message: "fixture error"}]}

      assert Process.get(counter_key) == 0,
             "after-compile transformer ran despite collected errors"
    end

    test "after-compile transformers DO run when no errors are produced (flag set)" do
      counter_key = {Spark.Test.CollectorFixture, :counter}
      Process.put(counter_key, 0)
      Process.put({Spark.Dsl, :test_collector}, self())

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.CollectedTransformerRuns do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_error(false)
            end
          end
        end)

      assert stderr == ""
      refute_received {Spark.Dsl, :verifier_errors, _, _}

      assert Process.get(counter_key) == 1,
             "after-compile transformer did not run for a valid module"
    end
  end

  describe "concurrent isolation" do
    test "two parallel processes each only see their own collected errors" do
      task_a =
        Task.async(fn ->
          Process.put({Spark.Dsl, :test_collector}, self())

          capture_io(:stderr, fn ->
            defmodule Elixir.CollectedConcurrentA do
              @moduledoc false
              use Spark.Test.Contact

              personal_details do
                first_name("Gandalf")
              end
            end
          end)

          drain_collector_messages([])
        end)

      task_b =
        Task.async(fn ->
          Process.put({Spark.Dsl, :test_collector}, self())

          capture_io(:stderr, fn ->
            defmodule Elixir.CollectedConcurrentB do
              @moduledoc false
              use Spark.Test.Contact

              personal_details do
                first_name("Gandalf")
              end
            end
          end)

          drain_collector_messages([])
        end)

      a_results = Task.await(task_a, 1_000)
      b_results = Task.await(task_b, 1_000)

      assert [{CollectedConcurrentA, [%Spark.Error.DslError{}]}] = a_results
      assert [{CollectedConcurrentB, [%Spark.Error.DslError{}]}] = b_results

      refute_received {Spark.Dsl, :verifier_errors, _, _}
    end
  end

  describe "warning hook" do
    test "unset flag triggers the default warn-to-stderr path" do
      Process.delete({Spark.Dsl, :test_collector})

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.WarnDefaultPath do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:bare)
            end
          end
        end)

      assert stderr =~ "fixture warning"
      refute_received {Spark.Dsl, :verifier_warnings, _, _}
    end

    test "non-pid collector value falls through to the default warn-to-stderr path" do
      Process.put({Spark.Dsl, :test_collector}, :not_a_pid)

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.WarnNonPidFlag do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:bare)
            end
          end
        end)

      assert stderr =~ "fixture warning"
      refute_received {Spark.Dsl, :verifier_warnings, _, _}
    end

    test "collector pid receives the warning as a single send" do
      Process.put({Spark.Dsl, :test_collector}, self())

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.WarnCollected do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:bare)
            end
          end
        end)

      assert stderr == ""

      assert_received {Spark.Dsl, :verifier_warnings, WarnCollected, [{"fixture warning", nil}]}
    end

    test "tuple-form warning {message, anno} is preserved through normalization" do
      Process.put({Spark.Dsl, :test_collector}, self())

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.WarnCollectedTuple do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:tuple)
            end
          end
        end)

      assert stderr == ""

      assert_received {Spark.Dsl, :verifier_warnings, WarnCollectedTuple, payloads}
      assert [{"fixture warning with location", anno}] = payloads
      assert anno != nil
    end

    test "multiple warnings from one verifier are delivered in a single message" do
      Process.put({Spark.Dsl, :test_collector}, self())

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.WarnCollectedMulti do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:multi)
            end
          end
        end)

      assert stderr == ""

      assert_received {Spark.Dsl, :verifier_warnings, WarnCollectedMulti, payloads}
      assert [{"fixture warning a", nil}, {"fixture warning b", anno}] = payloads
      assert anno != nil
    end

    test "errors and warnings from one module are routed via their own tags" do
      Process.put({Spark.Dsl, :test_collector}, self())

      stderr =
        capture_io(:stderr, fn ->
          defmodule Elixir.WarnAndErrorCollected do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_error(true)
              trigger_warning(:bare)
            end
          end
        end)

      assert stderr == ""

      assert_received {Spark.Dsl, :verifier_errors, WarnAndErrorCollected,
                       [%Spark.Error.DslError{message: "fixture error"}]}

      assert_received {Spark.Dsl, :verifier_warnings, WarnAndErrorCollected,
                       [{"fixture warning", nil}]}
    end
  end

  defp drain_collector_messages(acc) do
    receive do
      {Spark.Dsl, :verifier_errors, mod, errs} -> drain_collector_messages([{mod, errs} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
