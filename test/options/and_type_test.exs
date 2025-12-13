# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Options.AndTypeTest do
  @moduledoc false

  use ExUnit.Case

  describe "{:and, subtypes}" do
    test "validates when value matches all subtypes" do
      schema = [value: [type: {:and, [:integer, :pos_integer]}]]

      assert {:ok, [value: 5]} = Spark.Options.validate([value: 5], schema)
    end

    test "fails when value doesn't match any subtype" do
      schema = [value: [type: {:and, [:integer, :pos_integer]}]]

      assert {:error, %Spark.Options.ValidationError{}} =
               Spark.Options.validate([value: "not an integer"], schema)
    end

    test "fails when value matches first subtype but not second" do
      schema = [value: [type: {:and, [:integer, :pos_integer]}]]

      assert {:error, %Spark.Options.ValidationError{}} =
               Spark.Options.validate([value: -5], schema)
    end

    test "fails when value matches second subtype but not first" do
      schema = [value: [type: {:and, [:pos_integer, {:in, [1, 2, 3]}]}]]

      assert {:error, %Spark.Options.ValidationError{}} =
               Spark.Options.validate([value: 5], schema)
    end

    test "threads transformed values through subsequent subtypes" do
      # First subtype transforms the value, second validates the transformed value
      schema = [
        value: [
          type:
            {:and,
             [
               {:custom, __MODULE__, :double_value, []},
               {:in, [10, 20, 30]}
             ]}
        ]
      ]

      # 5 gets doubled to 10, which is in [10, 20, 30]
      assert {:ok, [value: 10]} = Spark.Options.validate([value: 5], schema)

      # 7 gets doubled to 14, which is NOT in [10, 20, 30]
      assert {:error, %Spark.Options.ValidationError{}} =
               Spark.Options.validate([value: 7], schema)
    end

    test "works with three or more subtypes" do
      schema = [
        value: [type: {:and, [:integer, :pos_integer, {:in, 1..10}]}]
      ]

      assert {:ok, [value: 5]} = Spark.Options.validate([value: 5], schema)

      assert {:error, %Spark.Options.ValidationError{}} =
               Spark.Options.validate([value: 15], schema)
    end

    test "works with keyword_list subtype" do
      schema = [
        config: [
          type:
            {:and,
             [
               :keyword_list,
               {:keyword_list, [name: [type: :string, required: true]]}
             ]}
        ]
      ]

      assert {:ok, [config: [name: "test"]]} =
               Spark.Options.validate([config: [name: "test"]], schema)

      assert {:error, %Spark.Options.ValidationError{}} =
               Spark.Options.validate([config: []], schema)
    end

    test "works with non_empty_keyword_list subtype" do
      schema = [
        config: [
          type:
            {:and,
             [
               :non_empty_keyword_list,
               {:keyword_list, [name: [type: :string]]}
             ]}
        ]
      ]

      assert {:ok, [config: [name: "test"]]} =
               Spark.Options.validate([config: [name: "test"]], schema)

      assert {:error, %Spark.Options.ValidationError{}} =
               Spark.Options.validate([config: []], schema)
    end

    test "works with map subtype" do
      schema = [
        config: [
          type:
            {:and,
             [
               :map,
               {:map, [name: [type: :string, required: true]]}
             ]}
        ]
      ]

      assert {:ok, [config: %{name: "test"}]} =
               Spark.Options.validate([config: %{name: "test"}], schema)

      assert {:error, %Spark.Options.ValidationError{}} =
               Spark.Options.validate([config: %{}], schema)
    end

    test "error message mentions all failing subtypes" do
      schema = [value: [type: {:and, [:integer, :string]}]]

      assert {:error, %Spark.Options.ValidationError{message: message}} =
               Spark.Options.validate([value: :atom], schema)

      assert message =~ "integer"
      assert message =~ "string"
    end
  end

  # Helper function for custom type that doubles the value
  def double_value(value) when is_integer(value), do: {:ok, value * 2}
  def double_value(value), do: {:error, "expected integer, got: #{inspect(value)}"}
end
