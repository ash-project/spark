defmodule Spark.Options.SimpleMixedAtomTupleListTest do
  @moduledoc false

  use ExUnit.Case

  require Spark.Options.Validator

  defmodule MySimpleMixedAtomTupleListSchema do
    @list_type {:in, [:atom, {:tuple, :keyword_list}]}

    @schema [
      schema: [
        type: {:wrap_list, @list_type},
      ]
    ]

    use Spark.Options.Validator, schema: @schema
  end

  describe "mixed wrap_list types" do
    test "can use only atoms" do
      MySimpleMixedAtomTupleListSchema.validate!(schema: :foo)
      MySimpleMixedAtomTupleListSchema.validate!(schema: [:foo, :bar])
      MySimpleMixedAtomTupleListSchema.validate!(schema: [:foo, :bar, :baz])
    end

    test "can use only keywords" do
      MySimpleMixedAtomTupleListSchema.validate!(
        schema: [
          foo: [enabled?: true],
        ]
      )
      MySimpleMixedAtomTupleListSchema.validate!(
        schema: [
          foo: [enabled?: true],
          bar: [enabled?: false],
        ]
      )
      MySimpleMixedAtomTupleListSchema.validate!(
        schema: [
          foo: [enabled?: true],
          bar: [enabled?: false],
          baz: [enabled?: false],
        ]
      )
    end
  end
end
