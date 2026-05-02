# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.AssertDslWarningTest do
  @moduledoc """
  Tests for `Spark.Test.assert_dsl_warning/1` and
  `Spark.Test.assert_dsl_warning/2` — pattern-match a single collected
  verifier warning payload.

  Modules defined inside the macro's anonymous-function body use the
  `Elixir.SomeName` form so that the bare alias used in outer assertions
  resolves to the same atom (see `Spark.Test.DslWarningsTest` and
  `Spark.Dsl.TestCollectorTest` for the convention).
  """

  use ExUnit.Case, async: true

  import Spark.Test

  describe "assert_dsl_warning/2" do
    test "passes when a matching warning exists and returns the matched payload" do
      payload =
        assert_dsl_warning {"fixture warning", _location} do
          defmodule Elixir.AssertWarnMatchBare do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:bare)
            end
          end
        end

      assert {message, nil} = payload
      assert message == "fixture warning"
    end

    test "pattern with non-literal positions matches correctly" do
      payload =
        assert_dsl_warning {_message, _location} do
          defmodule Elixir.AssertWarnWildcard do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:tuple)
            end
          end
        end

      assert {"fixture warning with location", anno} = payload
      assert anno != nil
    end

    test "fails with a helpful message when no warnings are collected" do
      failure =
        assert_raise ExUnit.AssertionError, fn ->
          assert_dsl_warning {"fixture warning", _} do
            defmodule Elixir.AssertWarnNoneClean do
              @moduledoc false
              use Spark.Test.CollectorFixture
            end
          end
        end

      assert failure.message =~ "verifier warning"
      assert failure.message =~ "fixture warning"
      assert failure.message =~ "Got:"
    end

    test "fails with a helpful message when warnings exist but none match" do
      failure =
        assert_raise ExUnit.AssertionError, fn ->
          assert_dsl_warning {"some other text", _} do
            defmodule Elixir.AssertWarnNoMatch do
              @moduledoc false
              use Spark.Test.CollectorFixture

              fixture do
                trigger_warning(:bare)
              end
            end
          end
        end

      assert failure.message =~ "some other text"
      assert failure.message =~ "fixture warning"
    end

    test "returns the first matching warning in definition order when multiple match" do
      payload =
        assert_dsl_warning {_message, _location} do
          defmodule Elixir.AssertWarnFirstBare do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:bare)
            end
          end

          defmodule Elixir.AssertWarnFirstTuple do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:tuple)
            end
          end
        end

      # Definition order is :bare first → first match is the bare-shape payload.
      assert {"fixture warning", nil} = payload
    end
  end

  describe "assert_dsl_warning/1" do
    test "passes when any warning exists and returns the first one" do
      payload =
        assert_dsl_warning do
          defmodule Elixir.AssertWarnAny do
            @moduledoc false
            use Spark.Test.CollectorFixture

            fixture do
              trigger_warning(:bare)
            end
          end
        end

      assert {"fixture warning", nil} = payload
    end

    test "fails with a helpful message when no warnings exist" do
      failure =
        assert_raise ExUnit.AssertionError, fn ->
          assert_dsl_warning do
            defmodule Elixir.AssertWarnAnyClean do
              @moduledoc false
              use Spark.Test.CollectorFixture
            end
          end
        end

      assert failure.message =~ "verifier warning"
      assert failure.message =~ "Got:"
    end
  end
end
