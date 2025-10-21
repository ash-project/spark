# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule SparkTest do
  use ExUnit.Case
  doctest Spark
  doctest Spark.Options

  describe inspect(&Spark.implements_behaviour?/2) do
    test "returns true if the module implements the specified behavior" do
      defmodule TestModule do
        @callback foo :: any()

        @behaviour TestModule

        def foo, do: :ok
      end

      refute Spark.implements_behaviour?(TestModule, AnyOtherModule)
      assert Spark.implements_behaviour?(TestModule, TestModule)
    end
  end
end
