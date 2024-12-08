defmodule Spark.Options.MixedListTypeTest do
  @moduledoc false

  use ExUnit.Case

  require Spark.Options.Validator

  defmodule MyMixedListSchema do
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
        type: {:list, @list_type},
      ]
    ]

    use Spark.Options.Validator, schema: @schema
  end

  describe "mixed list types" do
    test "can use only atoms" do
      MyMixedListSchema.validate!(schema: [:foo])
      MyMixedListSchema.validate!(schema: [:foo, :bar])
      MyMixedListSchema.validate!(schema: [:foo, :bar, :baz])
    end

    test "can use only keywords" do
      MyMixedListSchema.validate!(
        schema: [
          foo: [enabled?: true],
        ]
      )
      MyMixedListSchema.validate!(
        schema: [
          foo: [enabled?: true],
          bar: [enabled?: false],
        ]
      )
      MyMixedListSchema.validate!(
        schema: [
          foo: [enabled?: true],
          bar: [enabled?: false],
          baz: [enabled?: false],
        ]
      )
      MyMixedListSchema.validate!(
        schema: [
          foo: [enabled?: true],
          bar: [],
          baz: [enabled?: false],
        ]
      )
    end

    test "can mix atoms and keywords" do
      MyMixedListSchema.validate!(schema: [:foo, bar: [enabled?: true]])
      MyMixedListSchema.validate!(schema: [:foo, bar: [enabled?: true], baz: [enabled?: true]])
      MyMixedListSchema.validate!(schema: [:foo, [bar: [enabled?: true]], :baz])
    end
  end
end
