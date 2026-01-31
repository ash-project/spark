# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Options.ValidatorTest do
  use ExUnit.Case
  require Spark.Options.Validator

  defmodule MySchema do
    @schema [
      foo: [
        type: :string,
        required: true
      ],
      bar: [
        type: :string,
        default: "default"
      ],
      baz: [
        type: :integer,
        default: 10
      ],
      buz: [
        type: {:custom, __MODULE__, :anything, []}
      ]
    ]

    def anything(value), do: {:ok, value}

    use Spark.Options.Validator, schema: @schema, define_deprecated_access?: true
  end

  describe "definition" do
    test "it defines a struct" do
      assert MySchema.__struct__()
    end

    test "the keys are the same as the schema keys" do
      assert Map.keys(MySchema.__struct__()) -- [:__struct__, :__set__] ==
               Keyword.keys(MySchema.schema())
    end

    test "stores which keys were explicitly provided or have defaults" do
      assert MySchema.validate!(foo: "10", bar: "10").__set__ == [:foo, :bar, :baz]
    end

    test "to_options returns the validated values for keys that were provided" do
      assert MySchema.to_options(MySchema.validate!(foo: "10", bar: "10")) == [
               baz: 10,
               bar: "10",
               foo: "10"
             ]
    end

    test "custom types are properly escaped" do
      assert MySchema.to_options(MySchema.validate!(foo: "10", bar: "10", buz: "anything")) == [
               baz: 10,
               bar: "10",
               foo: "10",
               buz: "anything"
             ]
    end
  end
end
