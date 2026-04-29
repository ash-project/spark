# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.AssertDslErrorTest do
  @moduledoc """
  Tests for `Spark.Test.assert_dsl_error/1` and `Spark.Test.assert_dsl_error/2` —
  pattern-match a single collected verifier error.

  Modules defined inside the macro's anonymous-function body use the
  `Elixir.SomeName` form so that the bare alias used in outer assertions
  resolves to the same atom (see `Spark.Test.DslErrorsTest` and
  `Spark.Dsl.TestCollectorTest` for the same convention).
  """

  use ExUnit.Case, async: true

  import Spark.Test

  describe "assert_dsl_error/2" do
    test "passes when a matching error exists and returns the matched error" do
      err =
        assert_dsl_error %Spark.Error.DslError{path: [:personal_details, :first_name]} do
          defmodule Elixir.AssertMatchGandalf do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end

      assert %Spark.Error.DslError{} = err
      assert err.message =~ "Cannot be gandalf"
      assert err.path == [:personal_details, :first_name]
    end

    test "pattern with non-literal field positions matches correctly" do
      # `_` and bound names in field positions exercise match?'s pattern semantics
      # (it must accept any value, not require a literal).
      err =
        assert_dsl_error %Spark.Error.DslError{path: [:personal_details, _], message: _msg} do
          defmodule Elixir.AssertWildcardGandalf do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end

      assert err.path == [:personal_details, :first_name]
    end

    test "fails with a helpful message when no errors are collected" do
      failure =
        assert_raise ExUnit.AssertionError, fn ->
          assert_dsl_error %Spark.Error.DslError{path: [:personal_details, :first_name]} do
            defmodule Elixir.AssertNoErrorsValid do
              @moduledoc false
              use Spark.Test.Contact

              personal_details do
                first_name("Zach")
              end
            end
          end
        end

      assert failure.message =~ "Spark.Error.DslError"
      assert failure.message =~ ":personal_details"
      assert failure.message =~ "Got:"
    end

    test "fails with a helpful message when errors exist but none match" do
      failure =
        assert_raise ExUnit.AssertionError, fn ->
          assert_dsl_error %Spark.Error.DslError{path: [:something_else]} do
            defmodule Elixir.AssertNoMatchGandalf do
              @moduledoc false
              use Spark.Test.Contact

              personal_details do
                first_name("Gandalf")
              end
            end
          end
        end

      assert failure.message =~ ":something_else"
      assert failure.message =~ "Cannot be gandalf"
    end

    test "returns the first matching error in definition order when multiple match" do
      err =
        assert_dsl_error %Spark.Error.DslError{path: [:personal_details, :first_name]} do
          defmodule Elixir.AssertFirstMatchOne do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end

          defmodule Elixir.AssertFirstMatchTwo do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end

      assert err.module == AssertFirstMatchOne
    end
  end

  describe "assert_dsl_error/1" do
    test "passes when any error exists and returns the first one" do
      err =
        assert_dsl_error do
          defmodule Elixir.AssertAnyGandalf do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end

      assert %Spark.Error.DslError{} = err
      assert err.message =~ "Cannot be gandalf"
    end

    test "fails with a helpful message when no errors exist" do
      failure =
        assert_raise ExUnit.AssertionError, fn ->
          assert_dsl_error do
            defmodule Elixir.AssertAnyValid do
              @moduledoc false
              use Spark.Test.Contact

              personal_details do
                first_name("Zach")
              end
            end
          end
        end

      assert failure.message =~ "Spark.Error.DslError"
      assert failure.message =~ "Got:"
    end
  end
end
