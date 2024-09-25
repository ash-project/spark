defmodule Spark.Options.ImplValidatorTest do
  use ExUnit.Case
  require Spark.Options.Validator

  defmodule MySchema do
    @schema [
      foo: [
        type: {:impl, Enumerable}
      ],
      bar: [
        type: {:impl, Integer}
      ],
      baz: [
        type: {:impl, ThisDoesNotReallyExist}
      ]
    ]

    use Spark.Options.Validator, schema: @schema, define_deprecated_access?: true
  end

  describe "impl option" do
    test "accepts a module for which a protocol is implemented" do
      MySchema.validate!(foo: List)
    end

    test "rejects a module for which a protocol is not implemented" do
      assert_raise(
        Spark.Options.ValidationError,
        "protocol Enumerable is not implemented by Enum",
        fn ->
          MySchema.validate!(foo: Enum)
        end
      )
    end

    test "rejects module that is not a protocol" do
      assert_raise(Spark.Options.ValidationError, "Integer is not a protocol", fn ->
        MySchema.validate!(bar: Enum)
      end)
    end

    test "rejects module that does not exist" do
      assert_raise(
        Spark.Options.ValidationError,
        "protocol Enumerable is not implemented by ThisDoesNotReallyExist",
        fn ->
          MySchema.validate!(foo: ThisDoesNotReallyExist)
        end
      )
    end

    test "rejects protocol name that is not a protocol" do
      assert_raise(
        Spark.Options.ValidationError,
        "ThisDoesNotReallyExist is not a protocol",
        fn ->
          MySchema.validate!(baz: Enum)
        end
      )
    end
  end
end
