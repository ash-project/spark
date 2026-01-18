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

  describe "new/1" do
    test "creates a section builder with the given name" do
      builder = Section.new(:attributes)
      assert builder.name == :attributes
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

  describe "schema/2" do
    test "sets the section schema" do
      builder =
        Section.new(:resource)
        |> Section.schema(generate_pk: [type: :boolean, default: true])

      assert builder.schema == [generate_pk: [type: :boolean, default: true]]
    end

    test "normalizes Field structs and tuples" do
      builder =
        Section.new(:resource)
        |> Section.schema([
          Field.new(:name) |> Field.type(:atom) |> Field.required(),
          {:strict, [type: :boolean, default: false]}
        ])

      assert builder.schema == [
               {:name, [type: :atom, required: true]},
               {:strict, [type: :boolean, default: false]}
             ]
    end
  end

  describe "option/3" do
    test "adds a single option to the schema" do
      builder =
        Section.new(:resource)
        |> Section.option(:strict, type: :boolean, default: false)
        |> Section.option(:name, type: :atom, required: true)

      assert builder.schema[:strict] == [type: :boolean, default: false]
      assert builder.schema[:name] == [type: :atom, required: true]
    end

    test "keeps the first schema entry when adding duplicates" do
      builder =
        Section.new(:resource)
        |> Section.option(:strict, type: :boolean)
        |> Section.option(:strict, type: :integer)

      assert Keyword.get_values(builder.schema, :strict) == [[type: :boolean]]
    end
  end

  describe "entity/2" do
    test "adds an entity to the section" do
      entity =
        Entity.new(:attribute, TestTarget)
        |> Entity.schema(name: [type: :atom])
        |> Entity.build!()

      builder =
        Section.new(:attributes)
        |> Section.entity(entity)

      assert length(builder.entities) == 1
      assert hd(builder.entities).name == :attribute
    end

    test "accepts a builder struct" do
      entity_builder =
        Entity.new(:attribute, TestTarget)
        |> Entity.schema(name: [type: :atom])

      builder =
        Section.new(:attributes)
        |> Section.entity(entity_builder)

      assert length(builder.entities) == 1
    end

    test "accepts a function" do
      builder =
        Section.new(:attributes)
        |> Section.entity(fn ->
          Entity.new(:attribute, TestTarget)
          |> Entity.schema(name: [type: :atom])
          |> Entity.build!()
        end)

      assert length(builder.entities) == 1
    end
  end

  describe "entities/2" do
    test "adds multiple entities at once" do
      e1 = Entity.new(:attr1, TestTarget) |> Entity.schema(name: [type: :atom])
      e2 = Entity.new(:attr2, TestTarget) |> Entity.schema(name: [type: :atom])

      builder =
        Section.new(:attributes)
        |> Section.entities([e1, e2])

      assert length(builder.entities) == 2
    end
  end

  describe "nested_section/2" do
    test "adds a nested section" do
      nested =
        Section.new(:advanced)
        |> Section.option(:debug, type: :boolean)
        |> Section.build!()

      builder =
        Section.new(:resource)
        |> Section.nested_section(nested)

      assert length(builder.sections) == 1
      assert hd(builder.sections).name == :advanced
    end

    test "accepts a builder struct" do
      nested_builder =
        Section.new(:advanced)
        |> Section.option(:debug, type: :boolean)

      builder =
        Section.new(:resource)
        |> Section.nested_section(nested_builder)

      assert length(builder.sections) == 1
    end

    test "accepts a function" do
      builder =
        Section.new(:resource)
        |> Section.nested_section(fn ->
          Section.new(:advanced)
          |> Section.option(:debug, type: :boolean)
          |> Section.build!()
        end)

      assert length(builder.sections) == 1
    end
  end

  describe "nested_sections/2" do
    test "adds multiple nested sections" do
      s1 = Section.new(:section1) |> Section.option(:opt1, type: :atom)
      s2 = Section.new(:section2) |> Section.option(:opt2, type: :atom)

      builder =
        Section.new(:parent)
        |> Section.nested_sections([s1, s2])

      assert length(builder.sections) == 2
    end
  end

  describe "configuration functions" do
    test "top_level/1 marks as top level" do
      builder = Section.new(:attributes) |> Section.top_level()
      assert builder.top_level? == true
    end

    test "top_level/2 can unset" do
      builder = Section.new(:attributes) |> Section.top_level(false)
      assert builder.top_level? == false
    end

    test "patchable/1 marks as patchable" do
      builder = Section.new(:attributes) |> Section.patchable()
      assert builder.patchable? == true
    end

    test "auto_set_fields/2 sets auto fields" do
      builder =
        Section.new(:special)
        |> Section.auto_set_fields(source: :dsl, internal: true)

      assert builder.auto_set_fields[:source] == :dsl
      assert builder.auto_set_fields[:internal] == true
    end

    test "after_define/2 sets callback" do
      builder =
        Section.new(:attributes)
        |> Section.after_define({MyModule, :process})

      assert builder.after_define == {MyModule, :process}
    end
  end

  describe "documentation functions" do
    test "describe/2 sets description" do
      builder = Section.new(:attributes) |> Section.describe("Resource attributes")
      assert builder.describe == "Resource attributes"
    end

    test "examples/2 sets all examples" do
      builder = Section.new(:attributes) |> Section.examples(["ex1", "ex2"])
      assert builder.examples == ["ex1", "ex2"]
    end

    test "example/2 appends an example" do
      builder =
        Section.new(:attributes)
        |> Section.example("ex1")
        |> Section.example("ex2")

      assert builder.examples == ["ex1", "ex2"]
    end

    test "snippet/2 sets snippet" do
      builder = Section.new(:attributes) |> Section.snippet("attributes do\n  ${1}\nend")
      assert builder.snippet == "attributes do\n  ${1}\nend"
    end

    test "links/2 sets links" do
      builder = Section.new(:attributes) |> Section.links(guides: ["docs/attrs.md"])
      assert builder.links == [guides: ["docs/attrs.md"]]
    end

    test "deprecations/2 sets deprecations" do
      builder = Section.new(:resource) |> Section.deprecations(old: "Use :new")
      assert builder.deprecations == [old: "Use :new"]
    end
  end

  describe "module functions" do
    test "imports/2 sets imports" do
      builder = Section.new(:actions) |> Section.imports([MyHelpers])
      assert builder.imports == [MyHelpers]
    end

    test "modules/2 sets module fields" do
      builder = Section.new(:resource) |> Section.modules([:base_module])
      assert builder.modules == [:base_module]
    end

    test "no_depend_modules/2 sets no-depend module fields" do
      builder = Section.new(:resource) |> Section.no_depend_modules([:optional])
      assert builder.no_depend_modules == [:optional]
    end
  end

  describe "build/1" do
    test "returns {:ok, section} on success" do
      {:ok, section} =
        Section.new(:attributes)
        |> Section.schema(strict: [type: :boolean])
        |> Section.build()

      assert %DslSection{} = section
      assert section.name == :attributes
      assert section.schema == [strict: [type: :boolean]]
    end

    test "returns error when name is missing" do
      builder = %Section{}
      assert {:error, "name is required"} = Section.build(builder)
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
  end

  describe "complete pipeline" do
    test "builds a fully configured section with entities and nested sections" do
      attribute_entity =
        Entity.new(:attribute, TestTarget)
        |> Entity.args([:name, :type])
        |> Entity.schema(
          name: [type: :atom, required: true],
          type: [type: :atom, required: true]
        )
        |> Entity.identifier(:name)

      advanced_section =
        Section.new(:advanced)
        |> Section.option(:debug, type: :boolean, default: false)
        |> Section.describe("Advanced configuration")

      section =
        Section.new(:attributes)
        |> Section.describe("Configure resource attributes")
        |> Section.schema(generate_primary_key: [type: :boolean, default: true])
        |> Section.entity(attribute_entity)
        |> Section.nested_section(advanced_section)
        |> Section.top_level()
        |> Section.patchable()
        |> Section.example("attributes do\n  attribute :name, :string\nend")
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
