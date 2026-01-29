# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.FieldTest do
  use ExUnit.Case, async: true

  alias Spark.Builder.Field

  describe "new/2" do
    test "creates a field with the given name and type" do
      field = Field.new(:my_field, :any)
      assert field.name == :my_field
      assert field.type == :any
      assert field.required == false
    end
  end

  describe "new/3" do
    test "applies provided options" do
      field =
        Field.new(:name, :atom,
          required?: true,
          default: :pending,
          doc: "The name"
        )

      assert field.type == :atom
      assert field.required == true
      assert field.default == :pending
      assert field.has_default == true
      assert field.doc == "The name"
    end

    test "works with complex types" do
      field = Field.new(:items, {:list, :atom})
      assert field.type == {:list, :atom}
    end

    test "supports nil defaults" do
      field = Field.new(:value, :any, default: nil)
      assert field.default == nil
      assert field.has_default == true
    end

    test "normalizes nested keys from raw keyword list" do
      field =
        Field.new(:config, :keyword_list,
          keys: [host: [type: :string], port: [type: :integer]]
        )

      assert field.keys == [host: [type: :string], port: [type: :integer]]
    end

    test "normalizes nested keys from Field builders" do
      field =
        Field.new(:config, :keyword_list,
          keys: [
            Field.new(:host, :string),
            Field.new(:port, :integer, default: 5432)
          ]
        )

      assert field.keys == [
               {:host, [type: :string]},
               {:port, [type: :integer, default: 5432]}
             ]
    end

    test "raises on invalid keys entries" do
      assert_raise ArgumentError, fn ->
        Field.new(:config, :keyword_list, keys: [:not_valid])
      end
    end

    test "sets documentation options" do
      field =
        Field.new(:handler, :any,
          doc: "The entity name",
          type_doc: "A function or MFA",
          subsection: "Advanced Options",
          links: [guides: ["docs/types.md"]]
        )

      assert field.doc == "The entity name"
      assert field.type_doc == "A function or MFA"
      assert field.subsection == "Advanced Options"
      assert field.links == [guides: ["docs/types.md"]]
    end

    test "accepts false documentation values" do
      field = Field.new(:internal, :any, doc: false, type_doc: false)
      assert field.doc == false
      assert field.type_doc == false
    end

    test "sets DSL support options" do
      field =
        Field.new(:source_field, :any,
          as: :source,
          snippet: "fn ${1:arg} -> ${2:body} end",
          deprecated: "Use :new_option instead"
        )

      assert field.as == :source
      assert field.snippet == "fn ${1:arg} -> ${2:body} end"
      assert field.deprecated == "Use :new_option instead"
    end

    test "sets metadata options" do
      spec = quote(do: map())

      field =
        Field.new(:internal, :any,
          private?: true,
          hide: [:docs, :schema],
          type_spec: spec
        )

      assert field.private? == true
      assert field.hide == [:docs, :schema]
      assert field.type_spec == spec
    end

    test "raises on unknown options" do
      assert_raise ArgumentError, ~r/Unknown field option/, fn ->
        Field.new(:name, :atom, unknown: :value)
      end
    end
  end

  describe "to_spec/1" do
    test "converts to schema tuple with minimal options" do
      {name, opts} = Field.new(:name, :any) |> Field.to_spec()

      assert name == :name
      # type: :any is the default, so it's excluded from opts
      assert opts == []
    end

    test "includes all set options" do
      {name, opts} =
        Field.new(:name, :atom, required?: true, doc: "The name")
        |> Field.to_spec()

      assert name == :name
      assert opts[:type] == :atom
      assert opts[:required] == true
      assert opts[:doc] == "The name"
    end

    test "includes default when set" do
      {_name, opts} =
        Field.new(:count, :integer, default: 0)
        |> Field.to_spec()

      assert opts[:default] == 0
    end

    test "excludes default values (required: false, private?: false)" do
      {_name, opts} =
        Field.new(:name, :atom)
        |> Field.to_spec()

      refute Keyword.has_key?(opts, :required)
      refute Keyword.has_key?(opts, :private?)
    end

    test "includes nested keys" do
      {_name, opts} =
        Field.new(:config, :keyword_list, keys: [host: [type: :string]])
        |> Field.to_spec()

      assert opts[:keys] == [host: [type: :string]]
    end
  end

  describe "to_schema/1" do
    test "builds complete schema from field list" do
      schema =
        [
          Field.new(:name, :atom, required?: true),
          Field.new(:count, :integer, default: 0)
        ]
        |> Field.to_schema()

      assert schema == [
               {:name, [type: :atom, required: true]},
               {:count, [type: :integer, default: 0]}
             ]
    end
  end

  describe "option construction" do
    test "supports full option-based construction" do
      {name, opts} =
        Field.new(:status, {:one_of, [:pending, :active, :completed]},
          default: :pending,
          doc: "Current status",
          deprecated: "Use :state instead"
        )
        |> Field.to_spec()

      assert name == :status
      assert opts[:type] == {:one_of, [:pending, :active, :completed]}
      assert opts[:default] == :pending
      assert opts[:doc] == "Current status"
      assert opts[:deprecated] == "Use :state instead"
    end
  end
end
