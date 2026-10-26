# SPDX-FileCopyrightText: 2026 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.DslOptsAttributeTest do
  use ExUnit.Case, async: false

  test "preserves another DSL's @opts when Spark is declared after it" do
    defmodule Elixir.GenericBeforeSpark do
      @moduledoc false

      use Spark.Test.GenericOptsDsl
      use Spark.Test.OptionAware, otp_app: :generic_before_spark
    end

    assert Elixir.GenericBeforeSpark.generic_dsl_options() == [owner: :generic_dsl]
    assert Elixir.GenericBeforeSpark.configured_otp_app() == :generic_before_spark
  end

  test "preserves Spark options when another DSL is declared after Spark" do
    defmodule Elixir.SparkBeforeGeneric do
      @moduledoc false

      use Spark.Test.OptionAware, otp_app: :spark_before_generic
      use Spark.Test.GenericOptsDsl
    end

    assert Elixir.SparkBeforeGeneric.generic_dsl_options() == [owner: :generic_dsl]
    assert Elixir.SparkBeforeGeneric.configured_otp_app() == :spark_before_generic
  end
end
