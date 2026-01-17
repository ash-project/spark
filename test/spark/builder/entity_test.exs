# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.EntityTest do
  use ExUnit.Case, async: true

  alias Spark.Builder.{Entity, Field}
  alias Spark.Builder.Type
  alias Spark.Dsl.Entity, as: DslEntity

  # Test target struct
  defmodule TestTarget do
    defstruct [:name, :type, :default, :__identifier__, :__spark_metadata__]
  end

  defmodule NestedTarget do
    defstruct [:value, :__spark_metadata__]
  end

  describe "struct alignment" do
    test "builder fields align with DSL entity fields" do
      builder_fields =
        %Entity{}
        |> Map.keys()
        |> List.delete(:__struct__)
        |> Enum.sort()

      dsl_fields = DslEntity.__field_names__() |> Enum.sort()

      assert builder_fields == dsl_fields
    end
  end

  describe "new/2" do
    test "creates an entity builder with name and target" do
      builder = Entity.new(:attribute, TestTarget)
      assert builder.name == :attribute
      assert builder.target == TestTarget
    end
  end

  describe "schema/2" do
    test "sets the schema" do
      builder =
        Entity.new(:attr, TestTarget)
        |> Entity.schema(name: [type: :atom], type: [type: :atom])

      assert builder.schema == [name: [type: :atom], type: [type: :atom]]
    end

    test "normalizes Field structs and tuples" do
      builder =
        Entity.new(:attr, TestTarget)
        |> Entity.schema([
          Field.new(:name) |> Field.type(:atom) |> Field.required(),
          {:type, [type: :atom]}
        ])

      assert builder.schema == [
               {:name, [type: :atom, required: true]},
               {:type, [type: :atom]}
             ]
    end
  end

  describe "field/3" do
    test "adds a field to the schema" do
      builder =
        Entity.new(:attr, TestTarget)
        |> Entity.field(:name, type: :atom, required: true)
        |> Entity.field(:type, type: :atom)

      assert builder.schema[:name] == [type: :atom, required: true]
      assert builder.schema[:type] == [type: :atom]
    end

    test "accepts a Field struct" do
      builder =
        Entity.new(:attr, TestTarget)
        |> Entity.field(Field.new(:name) |> Field.type(:atom))

      assert builder.schema[:name] == [type: :atom]
    end
  end

  describe "args/2" do
    test "sets positional arguments" do
      builder =
        Entity.new(:attr, TestTarget)
        |> Entity.args([:name, :type])

      assert builder.args == [:name, :type]
    end

    test "supports optional args" do
      builder =
        Entity.new(:attr, TestTarget)
        |> Entity.args([:name, {:optional, :type}, {:optional, :default, nil}])

      assert builder.args == [:name, {:optional, :type}, {:optional, :default, nil}]
    end
  end

  describe "identifier/2" do
    test "sets identifier field" do
      builder = Entity.new(:attr, TestTarget) |> Entity.identifier(:name)
      assert builder.identifier == :name
    end

    test "supports auto unique integer" do
      builder = Entity.new(:attr, TestTarget) |> Entity.identifier({:auto, :unique_integer})
      assert builder.identifier == {:auto, :unique_integer}
    end
  end

  describe "transform/2" do
    test "sets transform function" do
      builder =
        Entity.new(:attr, TestTarget)
        |> Entity.transform({MyModule, :validate, []})

      assert builder.transform == {MyModule, :validate, []}
    end
  end

  describe "nested_entity/3" do
    test "adds a nested entity" do
      nested =
        Entity.new(:nested, NestedTarget)
        |> Entity.schema(value: [type: :any])
        |> Entity.build!()

      builder =
        Entity.new(:parent, TestTarget)
        |> Entity.nested_entity(:children, nested)

      assert length(builder.entities[:children]) == 1
      assert hd(builder.entities[:children]).name == :nested
    end

    test "accepts a builder struct" do
      nested_builder =
        Entity.new(:nested, NestedTarget)
        |> Entity.schema(value: [type: :any])

      builder =
        Entity.new(:parent, TestTarget)
        |> Entity.nested_entity(:children, nested_builder)

      assert length(builder.entities[:children]) == 1
    end

    test "accepts a function" do
      builder =
        Entity.new(:parent, TestTarget)
        |> Entity.nested_entity(:children, fn ->
          Entity.new(:nested, NestedTarget)
          |> Entity.schema(value: [type: :any])
          |> Entity.build!()
        end)

      assert length(builder.entities[:children]) == 1
    end

    test "appends to existing entities" do
      nested1 = Entity.new(:nested1, NestedTarget) |> Entity.schema(value: [type: :any])
      nested2 = Entity.new(:nested2, NestedTarget) |> Entity.schema(value: [type: :any])

      builder =
        Entity.new(:parent, TestTarget)
        |> Entity.nested_entity(:children, nested1)
        |> Entity.nested_entity(:children, nested2)

      assert length(builder.entities[:children]) == 2
    end
  end

  describe "nested_entities/3" do
    test "adds multiple nested entities at once" do
      nested1 = Entity.new(:n1, NestedTarget) |> Entity.schema(value: [type: :any])
      nested2 = Entity.new(:n2, NestedTarget) |> Entity.schema(value: [type: :any])

      builder =
        Entity.new(:parent, TestTarget)
        |> Entity.nested_entities(:children, [nested1, nested2])

      assert length(builder.entities[:children]) == 2
    end
  end

  describe "singleton_entity_keys/2" do
    test "sets singleton keys" do
      builder =
        Entity.new(:parent, TestTarget)
        |> Entity.singleton_entity_keys([:primary_key])

      assert builder.singleton_entity_keys == [:primary_key]
    end
  end

  describe "recursive_as/2" do
    test "sets recursive key" do
      builder = Entity.new(:step, TestTarget) |> Entity.recursive_as(:steps)
      assert builder.recursive_as == :steps
    end
  end

  describe "auto_set_fields/2" do
    test "sets auto fields" do
      builder =
        Entity.new(:attr, TestTarget)
        |> Entity.auto_set_fields(kind: :attribute, source: :dsl)

      assert builder.auto_set_fields == [kind: :attribute, source: :dsl]
    end
  end

  describe "auto_set_field/3" do
    test "adds single auto field" do
      builder =
        Entity.new(:attr, TestTarget)
        |> Entity.auto_set_field(:internal, true)
        |> Entity.auto_set_field(:source, :dsl)

      assert builder.auto_set_fields[:internal] == true
      assert builder.auto_set_fields[:source] == :dsl
    end
  end

  describe "documentation functions" do
    test "describe/2 sets description" do
      builder = Entity.new(:attr, TestTarget) |> Entity.describe("An attribute")
      assert builder.describe == "An attribute"
    end

    test "examples/2 sets all examples" do
      builder = Entity.new(:attr, TestTarget) |> Entity.examples(["example 1", "example 2"])
      assert builder.examples == ["example 1", "example 2"]
    end

    test "example/2 appends an example" do
      builder =
        Entity.new(:attr, TestTarget)
        |> Entity.example("example 1")
        |> Entity.example("example 2")

      assert builder.examples == ["example 1", "example 2"]
    end

    test "snippet/2 sets snippet" do
      builder = Entity.new(:attr, TestTarget) |> Entity.snippet("attribute :${1:name}")
      assert builder.snippet == "attribute :${1:name}"
    end

    test "links/2 sets links" do
      builder = Entity.new(:attr, TestTarget) |> Entity.links(guides: ["docs/attrs.md"])
      assert builder.links == [guides: ["docs/attrs.md"]]
    end

    test "deprecations/2 sets deprecations" do
      builder = Entity.new(:attr, TestTarget) |> Entity.deprecations(old: "Use :new")
      assert builder.deprecations == [old: "Use :new"]
    end
  end

  describe "module functions" do
    test "imports/2 sets imports" do
      builder = Entity.new(:attr, TestTarget) |> Entity.imports([MyHelpers])
      assert builder.imports == [MyHelpers]
    end

    test "modules/2 sets module fields" do
      builder = Entity.new(:attr, TestTarget) |> Entity.modules([:module])
      assert builder.modules == [:module]
    end

    test "no_depend_modules/2 sets no-depend module fields" do
      builder = Entity.new(:attr, TestTarget) |> Entity.no_depend_modules([:optional])
      assert builder.no_depend_modules == [:optional]
    end

    test "hide/2 sets hidden fields" do
      builder = Entity.new(:attr, TestTarget) |> Entity.hide([:internal])
      assert builder.hide == [:internal]
    end
  end

  describe "build/1" do
    test "returns {:ok, entity} on success" do
      {:ok, entity} =
        Entity.new(:attr, TestTarget)
        |> Entity.schema(name: [type: :atom])
        |> Entity.build()

      assert %DslEntity{} = entity
      assert entity.name == :attr
      assert entity.target == TestTarget
      assert entity.schema == [name: [type: :atom]]
    end

    test "returns error when name is missing" do
      builder = %Entity{target: TestTarget}
      assert {:error, "name is required"} = Entity.build(builder)
    end

    test "returns error when target is missing" do
      builder = %Entity{name: :attr}
      assert {:error, "target is required"} = Entity.build(builder)
    end

    test "returns error when args reference undefined schema keys" do
      result =
        Entity.new(:attr, TestTarget)
        |> Entity.schema(name: [type: :atom])
        |> Entity.args([:name, :missing])
        |> Entity.build()

      assert {:error, message} = result
      assert message =~ "undefined schema keys"
      assert message =~ ":missing"
    end

    test "validates args with optional format" do
      {:ok, _entity} =
        Entity.new(:attr, TestTarget)
        |> Entity.schema(name: [type: :atom], type: [type: :atom])
        |> Entity.args([:name, {:optional, :type}])
        |> Entity.build()
    end

    test "returns error when args are duplicated" do
      result =
        Entity.new(:attr, TestTarget)
        |> Entity.schema(name: [type: :atom])
        |> Entity.args([:name, :name])
        |> Entity.build()

      assert {:error, message} = result
      assert message =~ "duplicate args"
      assert message =~ ":name"
    end

    test "allows optional arg default even when schema default differs" do
      {:ok, _entity} =
        Entity.new(:attr, TestTarget)
        |> Entity.schema(name: [type: :atom, default: :foo])
        |> Entity.args([{:optional, :name, :bar}])
        |> Entity.build()
    end

    test "allows optional arg default without schema default" do
      {:ok, _entity} =
        Entity.new(:attr, TestTarget)
        |> Entity.schema(name: [type: :atom])
        |> Entity.args([{:optional, :name, :foo}])
        |> Entity.build()
    end

    test "errors when singleton_entity_keys not in nested entities" do
      child =
        Entity.new(:child, NestedTarget)
        |> Entity.schema(value: [type: :any])

      result =
        Entity.new(:parent, TestTarget)
        |> Entity.nested_entity(:children, child)
        |> Entity.singleton_entity_keys([:missing])
        |> Entity.build()

      assert {:error, message} = result
      assert message =~ "undefined entity keys"
      assert message =~ ":missing"
    end

    test "succeeds when optional default matches schema default" do
      {:ok, _entity} =
        Entity.new(:attr, TestTarget)
        |> Entity.schema(name: [type: :atom, default: :foo])
        |> Entity.args([{:optional, :name, :foo}])
        |> Entity.build()
    end
  end

  describe "build!/1" do
    test "returns entity on success" do
      entity =
        Entity.new(:attr, TestTarget)
        |> Entity.schema(name: [type: :atom])
        |> Entity.build!()

      assert %DslEntity{} = entity
    end

    test "raises on validation error" do
      assert_raise ArgumentError, ~r/name is required/, fn ->
        %Entity{target: TestTarget} |> Entity.build!()
      end
    end
  end

  describe "complete pipeline" do
    test "builds a fully configured entity" do
      entity =
        Entity.new(:attribute, TestTarget)
        |> Entity.describe("Defines an attribute")
        |> Entity.args([:name, {:optional, :type, :string}])
        |> Entity.schema(
          name: [type: :atom, required: true, doc: "The attribute name"],
          type: [
            type: Type.one_of([:string, :integer, :boolean]),
            default: :string,
            doc: "The type"
          ],
          default: [type: :any, doc: "Default value"]
        )
        |> Entity.identifier(:name)
        |> Entity.example("attribute :email, :string")
        |> Entity.snippet("attribute :${1:name}, :${2:type}")
        |> Entity.build!()

      assert entity.name == :attribute
      assert entity.target == TestTarget
      assert entity.args == [:name, {:optional, :type, :string}]
      assert entity.identifier == :name
      assert length(entity.schema) == 3
      assert entity.describe == "Defines an attribute"
      assert entity.examples == ["attribute :email, :string"]
      assert entity.snippet == "attribute :${1:name}, :${2:type}"
    end
  end
end
