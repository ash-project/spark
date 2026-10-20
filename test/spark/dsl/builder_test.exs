# SPDX-FileCopyrightText: 2026 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Dsl.BuilderTest do
  use ExUnit.Case, async: true

  defmodule Builders do
    use Spark.Dsl.Builder

    defbuilder put_value(dsl_state, key, value \\ 1) do
      Map.put(dsl_state, key, value)
    end

    defbuilder put_ok(dsl_state, key) do
      {:ok, Map.put(dsl_state, key, true)}
    end

    defbuilder fail(_dsl_state) do
      {:error, :failed}
    end

    defbuilderp put_private(dsl_state, key, value \\ :private) do
      Map.put(dsl_state, key, value)
    end

    def call_private(dsl_state, key), do: put_private(dsl_state, key)
    def call_private(dsl_state, key, value), do: put_private(dsl_state, key, value)
  end

  describe "defbuilder" do
    test "wraps a plain return value in an ok tuple" do
      assert Builders.put_value(%{}, :a, 2) == {:ok, %{a: 2}}
    end

    test "applies default arguments" do
      assert Builders.put_value(%{}, :a) == {:ok, %{a: 1}}
    end

    test "unwraps an ok tuple input" do
      assert Builders.put_value({:ok, %{b: 1}}, :a) == {:ok, %{a: 1, b: 1}}
    end

    test "passes an error input through without running the body" do
      assert Builders.put_value({:error, :earlier}, :a) == {:error, :earlier}
    end

    test "returns ok and error tuples from the body unchanged" do
      assert Builders.put_ok(%{}, :a) == {:ok, %{a: true}}
      assert Builders.fail(%{}) == {:error, :failed}
    end
  end

  describe "defbuilderp" do
    test "defines private builder clauses" do
      refute function_exported?(Builders, :put_private, 2)
      refute function_exported?(Builders, :put_private, 3)

      assert Builders.call_private(%{}, :a) == {:ok, %{a: :private}}
      assert Builders.call_private({:ok, %{}}, :a, 2) == {:ok, %{a: 2}}
      assert Builders.call_private({:error, :earlier}, :a) == {:error, :earlier}
    end
  end
end
