# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.SectionTest do
  use ExUnit.Case, async: true

  alias Spark.Builder.{Entity, Field}
  alias Spark.Builder.Section
  alias Spark.Dsl.Section, as: DslSection

  # Test target struct for entities
  defmodule TestTarget do
    defstruct [:name, :type, :__identifier__, :__spark_metadata__]
  end

  describe "new/2" do
    test "creates a section builder with the given name" do
      builder = Section.new(:attributes)
      assert builder.name == :attributes
    end

    test "accepts schema option" do
      builder =
        Section.new(:resource,
          schema: [generate_pk: [type: :boolean, default: true]]
        )

      assert builder.schema == [generate_pk: [type: :boolean, default: true]]
    end

    test "normalizes Field structs and tuples in schema" do
      builder =
        Section.new(:resource,
          schema: [
            Field.new(:name, :atom, required: true),
            {:strict, [type: :boolean, default: false]}
          ]
        )

      assert builder.schema == [
               {:name, [type: :atom, required: true]},
               {:strict, [type: :boolean, default: false]}
             ]
    end

    test "accepts entities option with built entity" do
      entity =
        Entity.new(:attribute, TestTarget, schema: [name: [type: :atom]])
        |> Entity.build!()

      builder = Section.new(:attributes, entities: [entity])

      assert length(builder.entities) == 1
      assert hd(builder.entities).name == :attribute
    end

    test "accepts entities option with builder struct" do
      entity_builder =
        Entity.new(:attribute, TestTarget, schema: [name: [type: :atom]])

      builder = Section.new(:attributes, entities: [entity_builder])

      assert length(builder.entities) == 1
    end

    test "accepts multiple entities" do
      e1 = Entity.new(:attr1, TestTarget, schema: [name: [type: :atom]])
      e2 = Entity.new(:attr2, TestTarget, schema: [name: [type: :atom]])

      builder = Section.new(:attributes, entities: [e1, e2])

      assert length(builder.entities) == 2
    end

    test "accepts sections option with built section" do
      nested =
        Section.new(:advanced, schema: [debug: [type: :boolean]])
        |> Section.build!()

      builder = Section.new(:resource, sections: [nested])

      assert length(builder.sections) == 1
      assert hd(builder.sections).name == :advanced
    end

    test "accepts sections option with builder struct" do
      nested_builder =
        Section.new(:advanced, schema: [debug: [type: :boolean]])

      builder = Section.new(:resource, sections: [nested_builder])

      assert length(builder.sections) == 1
    end

    test "accepts multiple nested sections" do
      s1 = Section.new(:section1, schema: [opt1: [type: :atom]])
      s2 = Section.new(:section2, schema: [opt2: [type: :atom]])

      builder = Section.new(:parent, sections: [s1, s2])

      assert length(builder.sections) == 2
    end

    test "accepts top_level? option" do
      builder = Section.new(:attributes, top_level?: true)
      assert builder.top_level? == true
    end

    test "accepts patchable? option" do
      builder = Section.new(:attributes, patchable?: true)
      assert builder.patchable? == true
    end

    test "accepts auto_set_fields option" do
      builder =
        Section.new(:special,
          auto_set_fields: [source: :dsl, internal: true]
        )

      assert builder.auto_set_fields[:source] == :dsl
      assert builder.auto_set_fields[:internal] == true
    end

    test "accepts after_define option" do
      builder =
        Section.new(:attributes,
          after_define: {MyModule, :process}
        )

      assert builder.after_define == {MyModule, :process}
    end

    test "accepts describe option" do
      builder = Section.new(:attributes, describe: "Resource attributes")
      assert builder.describe == "Resource attributes"
    end

    test "accepts examples option" do
      builder = Section.new(:attributes, examples: ["ex1", "ex2"])
      assert builder.examples == ["ex1", "ex2"]
    end

    test "accepts snippet option" do
      builder = Section.new(:attributes, snippet: "attributes do\n  ${1}\nend")
      assert builder.snippet == "attributes do\n  ${1}\nend"
    end

    test "accepts links option" do
      builder = Section.new(:attributes, links: [guides: ["docs/attrs.md"]])
      assert builder.links == [guides: ["docs/attrs.md"]]
    end

    test "accepts deprecations option" do
      builder = Section.new(:resource, deprecations: [old: "Use :new"])
      assert builder.deprecations == [old: "Use :new"]
    end

    test "accepts imports option" do
      builder = Section.new(:actions, imports: [MyHelpers])
      assert builder.imports == [MyHelpers]
    end

    test "accepts modules option" do
      builder = Section.new(:resource, modules: [:base_module])
      assert builder.modules == [:base_module]
    end

    test "accepts no_depend_modules option" do
      builder = Section.new(:resource, no_depend_modules: [:optional])
      assert builder.no_depend_modules == [:optional]
    end
  end

  describe "struct alignment" do
    test "builder fields align with DSL section fields" do
      builder_fields =
        %Section{}
        |> Map.keys()
        |> List.delete(:__struct__)
        |> Enum.sort()

      dsl_fields = DslSection.__field_names__() |> Enum.sort()

      assert builder_fields == dsl_fields
    end
  end

  describe "build/1" do
    test "returns {:ok, section} on success" do
      {:ok, section} =
        Section.new(:attributes, schema: [strict: [type: :boolean]])
        |> Section.build()

      assert %DslSection{} = section
      assert section.name == :attributes
      assert section.schema == [strict: [type: :boolean]]
    end

    test "returns error when name is missing" do
      builder = %Section{}
      assert {:error, "name is required"} = Section.build(builder)
    end

    test "returns error when unknown builder options are provided" do
      result =
        Section.new(:attributes, top_level: true)
        |> Section.build()

      assert {:error, message} = result
      assert message =~ "unknown options"
      assert message =~ ":top_level"
    end

    test "returns error when after_define is invalid" do
      result =
        Section.new(:attributes, after_define: :not_a_tuple)
        |> Section.build()

      assert {:error, message} = result
      assert message =~ "after_define must be"
    end
  end

  describe "build!/1" do
    test "returns section on success" do
      section =
        Section.new(:attributes)
        |> Section.build!()

      assert %DslSection{} = section
    end

    test "raises on validation error" do
      assert_raise ArgumentError, ~r/name is required/, fn ->
        %Section{} |> Section.build!()
      end
    end

    test "raises on unknown builder options" do
      assert_raise ArgumentError, ~r/unknown options/, fn ->
        Section.new(:attributes, top_level: true)
        |> Section.build!()
      end
    end
  end

  describe "complete pipeline" do
    test "builds a fully configured section with entities and nested sections" do
      attribute_entity =
        Entity.new(:attribute, TestTarget,
          args: [:name, :type],
          schema: [
            name: [type: :atom, required: true],
            type: [type: :atom, required: true]
          ],
          identifier: :name
        )

      advanced_section =
        Section.new(:advanced,
          schema: [debug: [type: :boolean, default: false]],
          describe: "Advanced configuration"
        )

      section =
        Section.new(:attributes,
          describe: "Configure resource attributes",
          schema: [generate_primary_key: [type: :boolean, default: true]],
          entities: [attribute_entity],
          sections: [advanced_section],
          top_level?: true,
          patchable?: true,
          examples: ["attributes do\n  attribute :name, :string\nend"]
        )
        |> Section.build!()

      assert section.name == :attributes
      assert section.describe == "Configure resource attributes"
      assert section.schema == [generate_primary_key: [type: :boolean, default: true]]
      assert length(section.entities) == 1
      assert hd(section.entities).name == :attribute
      assert length(section.sections) == 1
      assert hd(section.sections).name == :advanced
      assert section.top_level? == true
      assert section.patchable? == true
      assert section.examples == ["attributes do\n  attribute :name, :string\nend"]
    end
  end
end
