# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.RefuteDslErrorsTest do
  @moduledoc """
  Tests for `Spark.Test.refute_dsl_errors/1` — assert that no verifier errors
  are produced by DSL modules defined inside the do-block.

  Modules defined inside the macro's anonymous-function body use the
  `Elixir.SomeName` form so that the bare alias used in outer assertions
  resolves to the same atom (see `Spark.Test.DslErrorsTest` and
  `Spark.Dsl.TestCollectorTest` for the convention).
  """

  use ExUnit.Case, async: true

  import Spark.Test

  describe "refute_dsl_errors/1" do
    test "passes when block defines no DSL modules" do
      assert refute_dsl_errors(do: :ok) == :ok
    end

    test "passes when DSL modules compile cleanly" do
      result =
        refute_dsl_errors do
          defmodule Elixir.RefuteValidContact do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Zach")
            end
          end
        end

      assert result == :ok
    end

    test "fails with a helpful message when an error exists" do
      failure =
        assert_raise ExUnit.AssertionError, fn ->
          refute_dsl_errors do
            defmodule Elixir.RefuteBadGandalf do
              @moduledoc false
              use Spark.Test.Contact

              personal_details do
                first_name("Gandalf")
              end
            end
          end
        end

      assert failure.message =~ "Expected no Spark.Error.DslError"
      assert failure.message =~ "Cannot be gandalf"
      assert failure.message =~ "RefuteBadGandalf"
    end

    test "fails when multiple modules produce errors and lists all of them" do
      failure =
        assert_raise ExUnit.AssertionError, fn ->
          refute_dsl_errors do
            defmodule Elixir.RefuteMultiOne do
              @moduledoc false
              use Spark.Test.Contact

              personal_details do
                first_name("Gandalf")
              end
            end

            defmodule Elixir.RefuteMultiTwo do
              @moduledoc false
              use Spark.Test.Contact

              personal_details do
                first_name("Gandalf")
              end
            end
          end
        end

      assert failure.message =~ "RefuteMultiOne"
      assert failure.message =~ "RefuteMultiTwo"
    end
  end
end
