# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.EntityTest do
  use ExUnit.Case, async: true

  alias Spark.Builder.{Entity, Field}
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

  describe "new/3" do
    test "creates an entity builder with name and target" do
      builder = Entity.new(:attribute, TestTarget)
      assert builder.name == :attribute
      assert builder.target == TestTarget
    end

    test "accepts schema option" do
      builder =
        Entity.new(:attr, TestTarget, schema: [name: [type: :atom], type: [type: :atom]])

      assert builder.schema == [name: [type: :atom], type: [type: :atom]]
    end

    test "normalizes Field structs and tuples in schema" do
      builder =
        Entity.new(:attr, TestTarget,
          schema: [
            Field.new(:name, :atom, required: true),
            {:type, [type: :atom]}
          ]
        )

      assert builder.schema == [
               {:name, [type: :atom, required: true]},
               {:type, [type: :atom]}
             ]
    end

    test "accepts args option" do
      builder = Entity.new(:attr, TestTarget, args: [:name, :type])
      assert builder.args == [:name, :type]
    end

    test "supports optional args" do
      builder =
        Entity.new(:attr, TestTarget,
          args: [:name, {:optional, :type}, {:optional, :default, nil}]
        )

      assert builder.args == [:name, {:optional, :type}, {:optional, :default, nil}]
    end

    test "accepts identifier option" do
      builder = Entity.new(:attr, TestTarget, identifier: :name)
      assert builder.identifier == :name
    end

    test "supports auto unique integer identifier" do
      builder = Entity.new(:attr, TestTarget, identifier: {:auto, :unique_integer})
      assert builder.identifier == {:auto, :unique_integer}
    end

    test "accepts transform option" do
      builder = Entity.new(:attr, TestTarget, transform: {MyModule, :validate, []})
      assert builder.transform == {MyModule, :validate, []}
    end

    test "accepts entities option with built entities" do
      nested =
        Entity.new(:nested, NestedTarget, schema: [value: [type: :any]])
        |> Entity.build!()

      builder =
        Entity.new(:parent, TestTarget, entities: [children: [nested]])

      assert length(builder.entities[:children]) == 1
      assert hd(builder.entities[:children]).name == :nested
    end

    test "accepts entities option with builder structs" do
      nested_builder =
        Entity.new(:nested, NestedTarget, schema: [value: [type: :any]])

      builder =
        Entity.new(:parent, TestTarget, entities: [children: [nested_builder]])

      assert length(builder.entities[:children]) == 1
    end

    test "accepts multiple entities under same key" do
      nested1 = Entity.new(:nested1, NestedTarget, schema: [value: [type: :any]])
      nested2 = Entity.new(:nested2, NestedTarget, schema: [value: [type: :any]])

      builder =
        Entity.new(:parent, TestTarget, entities: [children: [nested1, nested2]])

      assert length(builder.entities[:children]) == 2
    end

    test "accepts singleton_entity_keys option" do
      builder = Entity.new(:parent, TestTarget, singleton_entity_keys: [:primary_key])
      assert builder.singleton_entity_keys == [:primary_key]
    end

    test "accepts recursive_as option" do
      builder = Entity.new(:step, TestTarget, recursive_as: :steps)
      assert builder.recursive_as == :steps
    end

    test "accepts auto_set_fields option" do
      builder =
        Entity.new(:attr, TestTarget, auto_set_fields: [kind: :attribute, source: :dsl])

      assert builder.auto_set_fields == [kind: :attribute, source: :dsl]
    end

    test "accepts describe option" do
      builder = Entity.new(:attr, TestTarget, describe: "An attribute")
      assert builder.describe == "An attribute"
    end

    test "accepts examples option" do
      builder = Entity.new(:attr, TestTarget, examples: ["example 1", "example 2"])
      assert builder.examples == ["example 1", "example 2"]
    end

    test "accepts snippet option" do
      builder = Entity.new(:attr, TestTarget, snippet: "attribute :${1:name}")
      assert builder.snippet == "attribute :${1:name}"
    end

    test "accepts links option" do
      builder = Entity.new(:attr, TestTarget, links: [guides: ["docs/attrs.md"]])
      assert builder.links == [guides: ["docs/attrs.md"]]
    end

    test "accepts deprecations option" do
      builder = Entity.new(:attr, TestTarget, deprecations: [old: "Use :new"])
      assert builder.deprecations == [old: "Use :new"]
    end

    test "accepts imports option" do
      builder = Entity.new(:attr, TestTarget, imports: [MyHelpers])
      assert builder.imports == [MyHelpers]
    end

    test "accepts modules option" do
      builder = Entity.new(:attr, TestTarget, modules: [:module])
      assert builder.modules == [:module]
    end

    test "accepts no_depend_modules option" do
      builder = Entity.new(:attr, TestTarget, no_depend_modules: [:optional])
      assert builder.no_depend_modules == [:optional]
    end

    test "accepts hide option" do
      builder = Entity.new(:attr, TestTarget, hide: [:internal])
      assert builder.hide == [:internal]
    end
  end

  describe "build/1" do
    test "returns {:ok, entity} on success" do
      {:ok, entity} =
        Entity.new(:attr, TestTarget, schema: [name: [type: :atom]])
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

    test "returns error when unknown builder options are provided" do
      result =
        Entity.new(:attr, TestTarget, snipet: "attribute :${1:name}")
        |> Entity.build()

      assert {:error, message} = result
      assert message =~ "unknown options"
      assert message =~ ":snipet"
    end

    test "returns error when args reference undefined schema keys" do
      result =
        Entity.new(:attr, TestTarget,
          schema: [name: [type: :atom]],
          args: [:name, :missing]
        )
        |> Entity.build()

      assert {:error, message} = result
      assert message =~ "undefined schema keys"
      assert message =~ ":missing"
    end

    test "allows args when schema has wildcard" do
      {:ok, _entity} =
        Entity.new(:attr, TestTarget,
          schema: [*: [type: :any]],
          args: [:name, :missing]
        )
        |> Entity.build()
    end

    test "returns error when identifier is not in schema or auto_set_fields" do
      result =
        Entity.new(:attr, TestTarget,
          schema: [name: [type: :atom]],
          identifier: :missing
        )
        |> Entity.build()

      assert {:error, message} = result
      assert message =~ "identifier references undefined"
      assert message =~ ":missing"
    end

    test "allows identifier in auto_set_fields" do
      {:ok, _entity} =
        Entity.new(:attr, TestTarget,
          schema: [name: [type: :atom]],
          auto_set_fields: [source: :dsl],
          identifier: :source
        )
        |> Entity.build()
    end

    test "allows identifier when schema has wildcard" do
      {:ok, _entity} =
        Entity.new(:attr, TestTarget,
          schema: [*: [type: :any]],
          identifier: :anything
        )
        |> Entity.build()
    end

    test "allows identifier referencing :as alias" do
      {:ok, _entity} =
        Entity.new(:attr, TestTarget,
          schema: [source_field: [type: :atom, as: :source]],
          identifier: :source
        )
        |> Entity.build()
    end

    test "rejects identifier referencing original key when :as alias exists" do
      result =
        Entity.new(:attr, TestTarget,
          schema: [source_field: [type: :atom, as: :source]],
          identifier: :source_field
        )
        |> Entity.build()

      assert {:error, message} = result
      assert message =~ "identifier references undefined"
    end

    test "validates args with optional format" do
      {:ok, _entity} =
        Entity.new(:attr, TestTarget,
          schema: [name: [type: :atom], type: [type: :atom]],
          args: [:name, {:optional, :type}]
        )
        |> Entity.build()
    end

    test "returns error when args are duplicated" do
      result =
        Entity.new(:attr, TestTarget,
          schema: [name: [type: :atom]],
          args: [:name, :name]
        )
        |> Entity.build()

      assert {:error, message} = result
      assert message =~ "duplicate args"
      assert message =~ ":name"
    end

    test "allows optional arg default even when schema default differs" do
      {:ok, _entity} =
        Entity.new(:attr, TestTarget,
          schema: [name: [type: :atom, default: :foo]],
          args: [{:optional, :name, :bar}]
        )
        |> Entity.build()
    end

    test "allows optional arg default without schema default" do
      {:ok, _entity} =
        Entity.new(:attr, TestTarget,
          schema: [name: [type: :atom]],
          args: [{:optional, :name, :foo}]
        )
        |> Entity.build()
    end

    test "allows singleton_entity_keys not in nested entities" do
      child = Entity.new(:child, NestedTarget, schema: [value: [type: :any]])

      result =
        Entity.new(:parent, TestTarget,
          entities: [children: [child]],
          singleton_entity_keys: [:missing]
        )
        |> Entity.build()

      assert {:ok, entity} = result
      assert entity.singleton_entity_keys == [:missing]
    end

    test "succeeds when optional default matches schema default" do
      {:ok, _entity} =
        Entity.new(:attr, TestTarget,
          schema: [name: [type: :atom, default: :foo]],
          args: [{:optional, :name, :foo}]
        )
        |> Entity.build()
    end
  end

  describe "build!/1" do
    test "returns entity on success" do
      entity =
        Entity.new(:attr, TestTarget, schema: [name: [type: :atom]])
        |> Entity.build!()

      assert %DslEntity{} = entity
    end

    test "raises on validation error" do
      assert_raise ArgumentError, ~r/name is required/, fn ->
        %Entity{target: TestTarget} |> Entity.build!()
      end
    end

    test "raises on unknown builder options" do
      assert_raise ArgumentError, ~r/unknown options/, fn ->
        Entity.new(:attr, TestTarget, snipet: "attribute :${1:name}")
        |> Entity.build!()
      end
    end
  end

  describe "complete pipeline" do
    test "builds a fully configured entity" do
      entity =
        Entity.new(:attribute, TestTarget,
          describe: "Defines an attribute",
          args: [:name, {:optional, :type, :string}],
          schema: [
            name: [type: :atom, required: true, doc: "The attribute name"],
            type: [
              type: {:one_of, [:string, :integer, :boolean]},
              default: :string,
              doc: "The type"
            ],
            default: [type: :any, doc: "Default value"]
          ],
          identifier: :name,
          examples: ["attribute :email, :string"],
          snippet: "attribute :${1:name}, :${2:type}"
        )
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
