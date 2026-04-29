# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.DslErrorsTest do
  @moduledoc """
  Tests for `Spark.Test.dsl_errors/1` — collects verifier errors raised by
  Spark DSL modules defined inside the macro's do-block, returning them as
  structured data.

  Modules defined inside the macro's anonymous-function body use the
  `Elixir.SomeName` form so that the bare alias used in outer assertions
  resolves to the same atom (see `Spark.Dsl.TestCollectorTest` for the same
  convention and the underlying Elixir alias-scoping rationale).
  """

  use ExUnit.Case, async: true

  import Spark.Test

  doctest Spark.Test

  describe "dsl_errors/1" do
    test "empty block returns empty list" do
      assert dsl_errors(do: :ok) == []
    end

    test "one bad DSL module returns one entry with its errors" do
      result =
        dsl_errors do
          defmodule Elixir.OneBadGandalf do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end

      assert [{OneBadGandalf, [%Spark.Error.DslError{} = err]}] = result
      assert err.message =~ "Cannot be gandalf"
      assert err.path == [:personal_details, :first_name]
    end

    test "one valid DSL module returns empty list" do
      result =
        dsl_errors do
          defmodule Elixir.OneValidContact do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Zach")
            end
          end
        end

      assert result == []
    end

    test "multiple bad modules return entries in definition order" do
      result =
        dsl_errors do
          defmodule Elixir.MultiOrderOne do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end

          defmodule Elixir.MultiOrderTwo do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end

          defmodule Elixir.MultiOrderThree do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end

      assert [
               {MultiOrderOne, [%Spark.Error.DslError{}]},
               {MultiOrderTwo, [%Spark.Error.DslError{}]},
               {MultiOrderThree, [%Spark.Error.DslError{}]}
             ] = result
    end

    test "one module producing multiple errors returns them all" do
      result =
        dsl_errors do
          defmodule Elixir.MultiErrorPerModule do
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
        end

      assert [{MultiErrorPerModule, errors}] = result
      assert length(errors) == 2

      assert Enum.any?(errors, fn err ->
               is_struct(err, Spark.Error.DslError) and err.message =~ "Cannot be gandalf"
             end)

      assert Enum.any?(errors, fn err ->
               is_struct(err, Spark.Error.DslError) and err.message =~ "Got duplicate"
             end)
    end

    test "exception in block propagates and flag is cleaned up" do
      assert Process.get({Spark.Dsl, :test_collector}) == nil

      assert_raise RuntimeError, "boom", fn ->
        dsl_errors do
          raise "boom"
        end
      end

      assert Process.get({Spark.Dsl, :test_collector}) == nil
    end

    test "previous collector flag value is restored after the call" do
      Process.put({Spark.Dsl, :test_collector}, :prior_marker)

      try do
        assert dsl_errors(do: :ok) == []
        assert Process.get({Spark.Dsl, :test_collector}) == :prior_marker
      after
        Process.delete({Spark.Dsl, :test_collector})
      end
    end

    test "does not consume unrelated mailbox messages" do
      send(self(), :keep_a)
      send(self(), {:other, 42})

      result =
        dsl_errors do
          defmodule Elixir.HygieneGandalf do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end

      assert [{HygieneGandalf, [_]}] = result

      assert_received :keep_a
      assert_received {:other, 42}
    end

    test "nested invocation: inner does not leak to outer" do
      outer =
        dsl_errors do
          inner =
            dsl_errors do
              defmodule Elixir.NestedInnerGandalf do
                @moduledoc false
                use Spark.Test.Contact

                personal_details do
                  first_name("Gandalf")
                end
              end
            end

          send(self(), {:inner_result, inner})

          defmodule Elixir.NestedOuterGandalf do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              first_name("Gandalf")
            end
          end
        end

      assert [{NestedOuterGandalf, [_]}] = outer
      assert_received {:inner_result, inner}
      assert [{NestedInnerGandalf, [_]}] = inner
    end

    test "drains warnings from the mailbox after the call" do
      result =
        dsl_errors do
          defmodule Elixir.DslErrorsCrossDrain do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_error(true)
              trigger_warning(:bare)
            end
          end
        end

      assert [{DslErrorsCrossDrain, [%Spark.Error.DslError{message: "fixture error"}]}] = result
      refute_received {Spark.Dsl, :verifier_warnings, _, _}
    end
  end
end
