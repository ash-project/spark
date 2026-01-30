# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.DslIntegrationTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  defmodule Item do
    defstruct [:name, :kind, :count, :__identifier__, :__spark_metadata__]
  end

  defmodule Dsl do
    alias Spark.Builder.DslIntegrationTest.Item
    alias Spark.Builder.{Entity, Field, Section}

    use Spark.Dsl.Extension,
      sections: [
        Section.new(:items,
          entities: [
            Entity.new(:item, Item,
              args: [:name],
              schema: [
                Field.new(:name, :atom, required: true),
                Field.new(:kind, {:one_of, [:small, :large]}, required: true),
                Field.new(:count, :integer, default: 0)
              ],
              identifier: :name
            )
            |> Entity.build!()
          ]
        )
        |> Section.build!()
      ]

    use Spark.Dsl, default_extensions: [extensions: __MODULE__]
  end

  defmodule Example do
    use Spark.Builder.DslIntegrationTest.Dsl

    items do
      item :first do
        kind(:small)
      end

      item :second do
        kind(:large)
        count(3)
      end
    end
  end

  defmodule FullOptionsItem do
    defstruct [
      :name,
      :kind,
      :count,
      :source,
      :config,
      :meta,
      :hidden_field,
      :private_field,
      :type_spec_field,
      :__identifier__,
      :__spark_metadata__
    ]
  end

  defmodule FullOptionsDsl do
    alias Spark.Builder.DslIntegrationTest.FullOptionsItem
    alias Spark.Builder.{Entity, Field, Section}

    use Spark.Dsl.Extension,
      sections: [
        Section.new(:items,
          entities: [
            Entity.new(:item, FullOptionsItem,
              args: [:name],
              schema: [
                Field.new(:name, :atom, required: true, doc: "Item name"),
                Field.new(:kind, {:one_of, [:small, :large]},
                  required: true,
                  doc: "Item kind"
                ),
                Field.new(:count, :integer, default: 0, doc: "Item count"),
                Field.new(:source_field, :atom, as: :source, required: true),
                Field.new(:config, :keyword_list,
                  keys: [
                    host: [type: :string, doc: "Host"],
                    port: [type: :integer, default: 4000, doc: "Port"]
                  ],
                  subsection: "Config Options",
                  doc: "Configuration"
                ),
                Field.new(:meta, :string,
                  doc: "Metadata value",
                  type_doc: "meta-type",
                  links: [guides: ["docs/meta.md"]],
                  snippet: "meta ${1:value}",
                  deprecated: "Use :kind instead"
                ),
                Field.new(:hidden_field, :string, hide: [:docs]),
                Field.new(:private_field, :string, private?: true),
                Field.new(:type_spec_field, :any, type_spec: quote(do: term()))
              ],
              identifier: :name
            )
            |> Entity.build!()
          ]
        )
        |> Section.build!()
      ]

    use Spark.Dsl, default_extensions: [extensions: __MODULE__]
  end

  defp compile_full_options_module(body) do
    module =
      Module.concat(
        __MODULE__,
        "FullOptionsExample#{System.unique_integer([:positive])}"
      )

    dsl_module = FullOptionsDsl

    Code.compile_quoted(
      quote do
        defmodule unquote(module) do
          use unquote(dsl_module)
          unquote(body)
        end
      end
    )

    module
  end

  test "builder-defined DSL sections and entities work end-to-end" do
    [first, second] = Spark.Dsl.Extension.get_entities(Example, [:items])

    assert first.name == :first
    assert first.kind == :small
    assert first.count == 0

    assert second.name == :second
    assert second.kind == :large
    assert second.count == 3
  end

  test "builder-defined DSL supports required, defaults, and nested keys" do
    module =
      compile_full_options_module(
        quote do
          items do
            item :alpha do
              kind(:small)
              source_field(:external)
              config(host: "localhost", port: 4000)
            end
          end
        end
      )

    [item] = Spark.Dsl.Extension.get_entities(module, [:items])

    assert item.name == :alpha
    assert item.kind == :small
    assert item.count == 0
    assert item.source == :external
    assert item.config == [host: "localhost", port: 4000]
  end

  test "builder-defined DSL validates required and typed options" do
    assert_raise Spark.Error.DslError, fn ->
      compile_full_options_module(
        quote do
          items do
            item :alpha do
              source_field(:external)
            end
          end
        end
      )
    end

    assert_raise Spark.Error.DslError, fn ->
      compile_full_options_module(
        quote do
          items do
            item :alpha do
            end
          end
        end
      )
    end

    assert_raise Spark.Error.DslError, fn ->
      compile_full_options_module(
        quote do
          items do
            item :alpha do
            end
          end
        end
      )
    end
  end

  test "builder-defined DSL warns on deprecated options" do
    warning =
      capture_io(:stderr, fn ->
        compile_full_options_module(
          quote do
            items do
              item :alpha do
                kind(:small)
                source_field(:external)
                meta("test")
              end
            end
          end
        )
      end)

    assert warning =~ ":meta option is deprecated"
  end

  test "builder-defined DSL preserves schema metadata options" do
    [section] = FullOptionsDsl.sections()
    [entity] = section.entities
    schema = entity.schema

    assert schema[:kind][:required] == true
    assert schema[:source_field][:required] == true
    assert schema[:source_field][:as] == :source
    assert schema[:count][:default] == 0

    assert schema[:config][:type] == :keyword_list
    assert schema[:config][:subsection] == "Config Options"

    assert schema[:config][:keys] == [
             host: [type: :string, doc: "Host"],
             port: [type: :integer, default: 4000, doc: "Port"]
           ]

    assert schema[:meta][:doc] == "Metadata value"
    assert schema[:meta][:type_doc] == "meta-type"
    assert schema[:meta][:links] == [guides: ["docs/meta.md"]]
    assert schema[:meta][:snippet] == "meta ${1:value}"
    assert schema[:meta][:deprecated] == "Use :kind instead"
    assert schema[:hidden_field][:hide] == [:docs]
    assert schema[:private_field][:private?] == true
    assert Macro.to_string(schema[:type_spec_field][:type_spec]) == "term()"

    docs = Spark.Options.docs(schema)
    assert docs =~ "Config Options"
    assert docs =~ "Metadata value"
    assert docs =~ "meta-type"
    refute docs =~ ":hidden_field"

    search_data = Spark.Docs.search_data_for(FullOptionsDsl)

    refute Enum.any?(search_data, &(&1.anchor == "items-item-hidden_field"))
  end
end
