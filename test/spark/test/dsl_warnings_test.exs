# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.DslWarningsTest do
  @moduledoc """
  Tests for `Spark.Test.dsl_warnings/1` — collects verifier warnings raised by
  Spark DSL modules defined inside the macro's do-block, returning them as
  structured `[{module, [{message, location | nil}, ...]}, ...]` data.

  Modules defined inside the macro's anonymous-function body use the
  `Elixir.SomeName` form so that the bare alias used in outer assertions
  resolves to the same atom (see `Spark.Test.DslErrorsTest` and
  `Spark.Dsl.TestCollectorTest` for the convention).
  """

  use ExUnit.Case, async: true

  import Spark.Test

  setup do
    debug_info? = Code.get_compiler_option(:debug_info)
    Code.put_compiler_option(:debug_info, true)
    on_exit(fn -> Code.put_compiler_option(:debug_info, debug_info?) end)
    :ok
  end

  describe "dsl_warnings/1" do
    test "empty block returns empty list" do
      assert dsl_warnings(do: :ok) == []
    end

    test "one DSL module with a warning returns one entry with its payloads" do
      result =
        dsl_warnings do
          defmodule Elixir.OneWarningFixture do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:bare)
            end
          end
        end

      assert [{OneWarningFixture, [{"fixture warning", nil}]}] = result
    end

    test "one valid DSL module returns empty list" do
      result =
        dsl_warnings do
          defmodule Elixir.OneCleanFixture do
            @moduledoc false
            use Spark.Test.CollectorFixture
          end
        end

      assert result == []
    end

    test "multiple modules with warnings return entries in definition order" do
      result =
        dsl_warnings do
          defmodule Elixir.MultiWarnOne do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:bare)
            end
          end

          defmodule Elixir.MultiWarnTwo do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:bare)
            end
          end

          defmodule Elixir.MultiWarnThree do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:bare)
            end
          end
        end

      assert [
               {MultiWarnOne, [{"fixture warning", nil}]},
               {MultiWarnTwo, [{"fixture warning", nil}]},
               {MultiWarnThree, [{"fixture warning", nil}]}
             ] = result
    end

    test "one module producing multiple warnings returns them all" do
      result =
        dsl_warnings do
          defmodule Elixir.MultiWarnPerModule do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:multi)
            end
          end
        end

      assert [{MultiWarnPerModule, payloads}] = result
      assert [{"fixture warning a", nil}, {"fixture warning b", anno}] = payloads
      assert anno != nil
    end

    test "exception in block propagates and flag is cleaned up" do
      assert Process.get({Spark.Dsl, :test_collector}) == nil

      assert_raise RuntimeError, "boom", fn ->
        dsl_warnings do
          raise "boom"
        end
      end

      assert Process.get({Spark.Dsl, :test_collector}) == nil
    end

    test "previous collector flag value is restored after the call" do
      Process.put({Spark.Dsl, :test_collector}, :prior_marker)

      try do
        assert dsl_warnings(do: :ok) == []
        assert Process.get({Spark.Dsl, :test_collector}) == :prior_marker
      after
        Process.delete({Spark.Dsl, :test_collector})
      end
    end

    test "does not consume unrelated mailbox messages" do
      send(self(), :keep_a)
      send(self(), {:other, 42})

      result =
        dsl_warnings do
          defmodule Elixir.HygieneWarnFixture do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:bare)
            end
          end
        end

      assert [{HygieneWarnFixture, [{"fixture warning", nil}]}] = result

      assert_received :keep_a
      assert_received {:other, 42}
    end

    test "nested invocation: inner does not leak to outer" do
      outer =
        dsl_warnings do
          inner =
            dsl_warnings do
              defmodule Elixir.NestedInnerWarn do
                @moduledoc false
                use Spark.Test.CollectorFixture

                fixture do
                  trigger_warning(:bare)
                end
              end
            end

          send(self(), {:inner_result, inner})

          defmodule Elixir.NestedOuterWarn do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:bare)
            end
          end
        end

      assert [{NestedOuterWarn, [{"fixture warning", nil}]}] = outer
      assert_received {:inner_result, inner}
      assert [{NestedInnerWarn, [{"fixture warning", nil}]}] = inner
    end

    test "drains errors from the mailbox after the call" do
      result =
        dsl_warnings do
          defmodule Elixir.DslWarningsCrossDrain do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_error(true)
              trigger_warning(:bare)
            end
          end
        end

      assert [{DslWarningsCrossDrain, [{"fixture warning", nil}]}] = result
      refute_received {Spark.Dsl, :verifier_errors, _, _}
    end
  end
end
