defmodule Spark.Options.ValidatorTest do
  use ExUnit.Case
  require Spark.Options.Validator
  import ExUnit.CaptureLog

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
      assert Map.keys(MySchema.__struct__()) -- [:__struct__] == Keyword.keys(MySchema.schema())
    end
  end
end
