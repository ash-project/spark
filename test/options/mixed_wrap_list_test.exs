defmodule Spark.Options.MixedWrapListTypeTest do
  @moduledoc false

  use ExUnit.Case

  require Spark.Options.Validator

  defmodule MyMixedWrapListSchema do
    @foo_opts [
      enabled?: [type: :boolean, required?: true]
    ]
    @bar_opts [
      enabled?: [type: :boolean, required?: false]
    ]
    @baz_opts [
      enabled?: [type: :boolean, required?: false]
    ]

    @allowed_keys [:foo, :bar, :baz]

    @optional_key_opts [
      foo: {:non_empty_keyword_list, @foo_opts},
      bar: {:non_empty_keyword_list, @bar_opts},
      baz: {:non_empty_keyword_list, @baz_opts},
    ]

    @list_type {:in, @allowed_keys ++ @optional_key_opts}

    @schema [
      schema: [
        type: {:wrap_list, @list_type},
      ]
    ]

    use Spark.Options.Validator, schema: @schema
  end

  describe "mixed wrap_list types" do
    test "can use only atoms" do
      MyMixedWrapListSchema.validate!(schema: :foo)
      MyMixedWrapListSchema.validate!(schema: [:foo, :bar])
      MyMixedWrapListSchema.validate!(schema: [:foo, :bar, :baz])
    end

    test "can use only keywords" do
      MyMixedWrapListSchema.validate!(
        schema: [
          foo: [enabled?: true],
        ]
      )
      MyMixedWrapListSchema.validate!(
        schema: [
          foo: [enabled?: true],
          bar: [enabled?: false],
        ]
      )
      MyMixedWrapListSchema.validate!(
        schema: [
          foo: [enabled?: true],
          bar: [enabled?: false],
          baz: [enabled?: false],
        ]
      )
      MyMixedWrapListSchema.validate!(
        schema: [
          foo: [enabled?: true],
          bar: [],
          baz: [enabled?: false],
        ]
      )
    end

    test "can mix atoms and keywords" do
      MyMixedWrapListSchema.validate!(schema: [:foo, bar: [enabled?: true]])
      MyMixedWrapListSchema.validate!(schema: [:foo, bar: [enabled?: true], baz: [enabled?: true]])
      MyMixedWrapListSchema.validate!(schema: [:foo, [bar: [enabled?: true]], :baz])
    end
  end
end
