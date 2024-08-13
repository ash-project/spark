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
      ]
    ]

    use Spark.Options.Validator, schema: @schema, define_deprecated_access?: true
  end

  describe "definition" do
    test "it defines a struct" do
      assert MySchema.__struct__()
    end

    test "the keys are the same as the schema keys" do
      assert Map.keys(MySchema.__struct__()) -- [:__struct__, :__provided__] == Keyword.keys(MySchema.schema())
    end

    test "stores which keys were explicitly provided" do
      assert MySchema.validate!([foo: "10", bar: "10"]).__provided__ == [:bar, :foo]
    end

    test "to_options returns the validated values for keys that were provided" do
      assert MySchema.to_options(MySchema.validate!([foo: "10", bar: "10"])) == [foo: "10", bar: "10"]
    end
  end
end
