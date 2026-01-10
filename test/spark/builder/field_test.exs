# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.FieldTest do
  use ExUnit.Case, async: true

  alias Spark.Builder.Field
  alias Spark.Builder.Type

  describe "new/1" do
    test "creates a field with the given name" do
      field = Field.new(:my_field)
      assert field.name == :my_field
      assert field.type == :any
      assert field.required == false
    end
  end

  describe "type/2" do
    test "sets the type" do
      field = Field.new(:name) |> Field.type(:atom)
      assert field.type == :atom
    end

    test "works with complex types" do
      field = Field.new(:items) |> Field.type(Type.list(:atom))
      assert field.type == {:list, :atom}
    end
  end

  describe "required/1" do
    test "marks field as required" do
      field = Field.new(:name) |> Field.required()
      assert field.required == true
    end

    test "can unset required" do
      field = Field.new(:name) |> Field.required() |> Field.required(false)
      assert field.required == false
    end
  end

  describe "default/2" do
    test "sets default value" do
      field = Field.new(:count) |> Field.default(0)
      assert field.default == 0
      assert field.has_default == true
    end

    test "works with nil default" do
      field = Field.new(:value) |> Field.default(nil)
      assert field.default == nil
      assert field.has_default == true
    end
  end

  describe "keys/2" do
    test "sets nested schema with raw keyword list" do
      field =
        Field.new(:config)
        |> Field.type(:keyword_list)
        |> Field.keys(host: [type: :string], port: [type: :integer])

      assert field.keys == [host: [type: :string], port: [type: :integer]]
    end

    test "normalizes Field builders to specs" do
      field =
        Field.new(:config)
        |> Field.type(:keyword_list)
        |> Field.keys([
          Field.new(:host) |> Field.type(:string),
          Field.new(:port) |> Field.type(:integer) |> Field.default(5432)
        ])

      assert field.keys == [
               {:host, [type: :string]},
               {:port, [type: :integer, default: 5432]}
             ]
    end
  end

  describe "documentation functions" do
    test "doc/2 sets documentation" do
      field = Field.new(:name) |> Field.doc("The entity name")
      assert field.doc == "The entity name"
    end

    test "doc/2 accepts false to hide" do
      field = Field.new(:internal) |> Field.doc(false)
      assert field.doc == false
    end

    test "type_doc/2 sets type documentation" do
      field = Field.new(:handler) |> Field.type_doc("A function or MFA")
      assert field.type_doc == "A function or MFA"
    end

    test "subsection/2 sets documentation subsection" do
      field = Field.new(:timeout) |> Field.subsection("Advanced Options")
      assert field.subsection == "Advanced Options"
    end

    test "links/2 sets documentation links" do
      field = Field.new(:type) |> Field.links(guides: ["docs/types.md"])
      assert field.links == [guides: ["docs/types.md"]]
    end
  end

  describe "DSL support functions" do
    test "as/2 sets alias name" do
      field = Field.new(:source_field) |> Field.as(:source)
      assert field.as == :source
    end

    test "snippet/2 sets autocomplete snippet" do
      field = Field.new(:handler) |> Field.snippet("fn ${1:arg} -> ${2:body} end")
      assert field.snippet == "fn ${1:arg} -> ${2:body} end"
    end

    test "deprecated/2 sets deprecation message" do
      field = Field.new(:old_option) |> Field.deprecated("Use :new_option instead")
      assert field.deprecated == "Use :new_option instead"
    end

    test "rename_to/2 sets rename target" do
      field = Field.new(:old_name) |> Field.rename_to(:new_name)
      assert field.rename_to == :new_name
    end
  end

  describe "metadata functions" do
    test "private/1 marks as private" do
      field = Field.new(:internal) |> Field.private()
      assert field.private? == true
    end

    test "hide/2 sets hide contexts" do
      field = Field.new(:internal) |> Field.hide([:docs, :schema])
      assert field.hide == [:docs, :schema]
    end

    test "type_spec/2 sets custom typespec" do
      spec = quote(do: map())
      field = Field.new(:data) |> Field.type_spec(spec)
      assert field.type_spec == spec
    end
  end

  describe "to_spec/1" do
    test "converts to schema tuple with minimal options" do
      {name, opts} = Field.new(:name) |> Field.to_spec()

      assert name == :name
      # type: :any is the default, so it's excluded from opts
      assert opts == []
    end

    test "includes all set options" do
      {name, opts} =
        Field.new(:name)
        |> Field.type(:atom)
        |> Field.required()
        |> Field.doc("The name")
        |> Field.to_spec()

      assert name == :name
      assert opts[:type] == :atom
      assert opts[:required] == true
      assert opts[:doc] == "The name"
    end

    test "includes default when set" do
      {_name, opts} =
        Field.new(:count)
        |> Field.type(:integer)
        |> Field.default(0)
        |> Field.to_spec()

      assert opts[:default] == 0
    end

    test "excludes default values (required: false, private?: false)" do
      {_name, opts} =
        Field.new(:name)
        |> Field.type(:atom)
        |> Field.to_spec()

      refute Keyword.has_key?(opts, :required)
      refute Keyword.has_key?(opts, :private?)
    end

    test "includes nested keys" do
      {_name, opts} =
        Field.new(:config)
        |> Field.type(:keyword_list)
        |> Field.keys(host: [type: :string])
        |> Field.to_spec()

      assert opts[:keys] == [host: [type: :string]]
    end
  end

  describe "to_schema/1" do
    test "builds complete schema from field list" do
      schema =
        [
          Field.new(:name) |> Field.type(:atom) |> Field.required(),
          Field.new(:count) |> Field.type(:integer) |> Field.default(0)
        ]
        |> Field.to_schema()

      assert schema == [
               {:name, [type: :atom, required: true]},
               {:count, [type: :integer, default: 0]}
             ]
    end
  end

  describe "pipe chaining" do
    test "supports full pipeline construction" do
      {name, opts} =
        Field.new(:status)
        |> Field.type(Type.one_of([:pending, :active, :completed]))
        |> Field.default(:pending)
        |> Field.doc("Current status")
        |> Field.deprecated("Use :state instead")
        |> Field.to_spec()

      assert name == :status
      assert opts[:type] == {:one_of, [:pending, :active, :completed]}
      assert opts[:default] == :pending
      assert opts[:doc] == "Current status"
      assert opts[:deprecated] == "Use :state instead"
    end
  end
end
