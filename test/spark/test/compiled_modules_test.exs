# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.CompiledModulesTest do
  @moduledoc """
  Compiler-built modules run `@after_verify` in a process that cannot read the
  test process's dictionary. This used to collect nothing, so
  `refute_dsl_errors/1` passed on a module that *did* have an error.
  """

  use ExUnit.Case, async: true

  import Spark.Test

  defp source(name, option) do
    """
    defmodule Elixir.#{name} do
      @moduledoc false
      use Spark.Test.CollectorFixture

      fixture do
        #{option}
      end
    end
    """
  end

  test "dsl_errors/1 collects errors from a module built by Code.compile_string/1" do
    source = source("CompiledStringError", "trigger_error true")

    assert [{CompiledStringError, [%Spark.Error.DslError{} = err]}] =
             dsl_errors(do: Code.compile_string(source))

    assert err.message =~ "fixture error"
  end

  test "refute_dsl_errors/1 fails for a module built by Code.compile_string/1" do
    source = source("RefuteCompiledStringError", "trigger_error true")

    failure =
      assert_raise ExUnit.AssertionError, fn ->
        refute_dsl_errors(do: Code.compile_string(source))
      end

    assert failure.message =~ "Expected no Spark.Error.DslError"
    assert failure.message =~ "RefuteCompiledStringError"
  end

  test "dsl_warnings/1 collects warnings from a module built by Code.compile_string/1" do
    source = source("CompiledStringWarning", "trigger_warning :bare")

    assert [{CompiledStringWarning, [{"fixture warning", nil}]}] =
             dsl_warnings(do: Code.compile_string(source))
  end
end
