# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.RefuteDslWarningsTest do
  @moduledoc """
  Tests for `Spark.Test.refute_dsl_warnings/1` — assert that no verifier
  warnings are produced by DSL modules defined inside the do-block.

  Modules defined inside the macro's anonymous-function body use the
  `Elixir.SomeName` form so that the bare alias used in outer assertions
  resolves to the same atom (see `Spark.Test.DslWarningsTest` and
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

  describe "refute_dsl_warnings/1" do
    test "passes when block defines no DSL modules" do
      assert refute_dsl_warnings(do: :ok) == :ok
    end

    test "passes when DSL modules compile cleanly" do
      result =
        refute_dsl_warnings do
          defmodule Elixir.RefuteWarnValid do
            @moduledoc false
            use Spark.Test.CollectorFixture
          end
        end

      assert result == :ok
    end

    test "fails with a helpful message when a warning exists" do
      failure =
        assert_raise ExUnit.AssertionError, fn ->
          refute_dsl_warnings do
            defmodule Elixir.RefuteWarnBare do
              @moduledoc false
              use Spark.Test.CollectorFixture

              fixture do
                trigger_warning(:bare)
              end
            end
          end
        end

      assert failure.message =~ "Expected no verifier warnings"
      assert failure.message =~ "fixture warning"
      assert failure.message =~ "RefuteWarnBare"
    end

    test "fails when multiple modules produce warnings and lists all of them" do
      failure =
        assert_raise ExUnit.AssertionError, fn ->
          refute_dsl_warnings do
            defmodule Elixir.RefuteWarnMultiOne do
              @moduledoc false
              use Spark.Test.CollectorFixture

              fixture do
                trigger_warning(:bare)
              end
            end

            defmodule Elixir.RefuteWarnMultiTwo do
              @moduledoc false
              use Spark.Test.CollectorFixture

              fixture do
                trigger_warning(:bare)
              end
            end
          end
        end

      assert failure.message =~ "RefuteWarnMultiOne"
      assert failure.message =~ "RefuteWarnMultiTwo"
    end
  end
end
