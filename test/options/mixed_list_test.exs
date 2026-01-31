# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Options.MixedListTypeTest do
  @moduledoc false

  use ExUnit.Case

  require Spark.Options.Validator

  defmodule MyMixedListSchema do
    @option_spec [
      foo: [
        enabled?: [type: :boolean, required: true]
      ],
      bar: [
        enabled?: [type: :boolean, required: false]
      ],
      baz: [
        enabled?: [type: :boolean, required: false]
      ]
    ]

    @literals @option_spec |> Keyword.keys() |> Enum.map(&{:literal, &1})
    @tuples @option_spec
            |> Enum.map(fn {key, spec} ->
              {:tuple, [{:literal, key}, {:keyword_list, spec}]}
            end)

    @schema [
      schema: [
        type: {:list, {:or, @literals ++ @tuples}}
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
          foo: [enabled?: true]
        ]
      )

      MyMixedListSchema.validate!(
        schema: [
          foo: [enabled?: true],
          bar: [enabled?: false]
        ]
      )

      MyMixedListSchema.validate!(
        schema: [
          foo: [enabled?: true],
          bar: [enabled?: false],
          baz: [enabled?: false]
        ]
      )

      MyMixedListSchema.validate!(
        schema: [
          foo: [enabled?: true],
          bar: [],
          baz: [enabled?: false]
        ]
      )
    end

    test "can mix atoms and keywords" do
      MyMixedListSchema.validate!(schema: [:foo, bar: [enabled?: true]])
      MyMixedListSchema.validate!(schema: [:foo, bar: [enabled?: true], baz: [enabled?: true]])
      MyMixedListSchema.validate!(schema: [:foo, :baz, bar: [enabled?: true]])
    end
  end
end
