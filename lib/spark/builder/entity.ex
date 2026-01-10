# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.Entity do
  @moduledoc """
  Builder for constructing `Spark.Dsl.Entity` structs.

  This module provides a fluent, pipe-based API for creating DSL entity
  definitions programmatically. Entities represent DSL constructors that
  produce struct instances.

  ## Examples

      alias Spark.Builder.Entity

      entity = Entity.new(:attribute, MyApp.Attribute)
        |> Entity.describe("Defines an attribute on the resource")
        |> Entity.args([:name, :type])
        |> Entity.schema([
          name: [type: :atom, required: true, doc: "The attribute name"],
          type: [type: :atom, required: true, doc: "The attribute type"],
          default: [type: :any, doc: "Default value"]
        ])
        |> Entity.identifier(:name)
        |> Entity.example("attribute :email, :string")
        |> Entity.build!()

  ## Nested Entities

  Entities can contain nested entities using `nested_entity/3`:

      Entity.new(:field, MyApp.Field)
        |> Entity.nested_entity(:validations, fn ->
          Entity.new(:validation, MyApp.Validation)
          |> Entity.args([:type])
          |> Entity.schema([type: [type: :atom, required: true]])
          |> Entity.build!()
        end)
        |> Entity.build!()
  """

  alias Spark.Builder.Field
  alias Spark.Builder.Helpers
  alias Spark.Dsl.Entity, as: DslEntity

  @fields Spark.Dsl.Entity.__fields__()

  defstruct @fields

  @type t :: %__MODULE__{
          name: atom() | nil,
          target: module() | nil,
          schema: Spark.Options.schema(),
          args: [atom() | {:optional, atom()} | {:optional, atom(), any()}],
          entities: keyword([DslEntity.t()]),
          singleton_entity_keys: [atom()],
          auto_set_fields: keyword(),
          identifier: term(),
          transform: DslEntity.transform(),
          recursive_as: atom() | nil,
          examples: [String.t()],
          describe: String.t(),
          snippet: String.t(),
          imports: [module()],
          modules: [atom()],
          no_depend_modules: [atom()],
          hide: [atom()],
          links: keyword([String.t()]) | nil,
          deprecations: keyword(String.t()),
          docs: String.t()
        }

  # ===========================================================================
  # Constructor
  # ===========================================================================

  @doc """
  Creates a new entity builder with the given name and target struct module.

  ## Parameters

    - `name` - The atom name for the DSL entity (e.g., `:attribute`)
    - `target` - The module of the struct that will be built

  ## Examples

      iex> Entity.new(:attribute, MyApp.Attribute)
      %Spark.Builder.Entity{name: :attribute, target: MyApp.Attribute}
  """
  @spec new(atom(), module()) :: t()
  def new(name, target) when is_atom(name) and is_atom(target) do
    %__MODULE__{name: name, target: target}
  end

  # ===========================================================================
  # Schema & Arguments
  # ===========================================================================

  @doc """
  Sets the schema for the entity.

  The schema defines what options the entity accepts and their types.
  Accepts raw `{name, opts}` tuples or `Spark.Builder.Field` structs and
  normalizes them to `Spark.Options` format.

  ## Examples

      Entity.new(:field, Field)
      |> Entity.schema([
        name: [type: :atom, required: true],
        type: [type: {:one_of, [:string, :integer]}]
      ])
  """
  @spec schema(t(), Spark.Options.schema()) :: t()
  def schema(%__MODULE__{} = builder, schema) when is_list(schema) do
    %{builder | schema: Field.to_schema(schema)}
  end

  @doc """
  Adds a single field to the schema.

  This is an alternative to `schema/2` for building schemas incrementally.
  Accepts raw `{name, opts}` tuples or `Spark.Builder.Field` structs.

  ## Examples

      Entity.new(:field, Field)
      |> Entity.field(:name, type: :atom, required: true, doc: "The name")
      |> Entity.field(:value, type: :any)
  """
  @spec field(t(), Field.t()) :: t()
  def field(%__MODULE__{} = builder, %Field{} = field) do
    merge_schema(builder, Field.to_schema([field]))
  end

  @spec field(t(), {atom(), keyword()}) :: t()
  def field(%__MODULE__{} = builder, {name, opts}) when is_atom(name) and is_list(opts) do
    merge_schema(builder, Field.to_schema([{name, opts}]))
  end

  @spec field(t(), atom(), keyword()) :: t()
  def field(%__MODULE__{} = builder, name, opts \\ []) when is_atom(name) and is_list(opts) do
    merge_schema(builder, Field.to_schema([{name, opts}]))
  end

  @doc """
  Sets the positional arguments for the entity.

  Arguments reference keys in the schema and define what can be passed
  positionally when using the DSL.

  ## Argument formats

    - Atom for required args: `:name`
    - `{:optional, :name}` for optional args
    - `{:optional, :name, default}` for optional args with defaults

  ## Examples

      Entity.new(:attribute, Attribute)
      |> Entity.args([:name, :type])

      Entity.new(:attribute, Attribute)
      |> Entity.args([:name, {:optional, :type, :string}])
  """
  @spec args(t(), [atom() | {:optional, atom()} | {:optional, atom(), any()}]) :: t()
  def args(%__MODULE__{} = builder, args) when is_list(args) do
    %{builder | args: args}
  end

  # ===========================================================================
  # Identity & Transformation
  # ===========================================================================

  @doc """
  Sets the identifier field for the entity.

  The identifier is used for uniqueness validation within a section.
  Use `{:auto, :unique_integer}` for auto-generated unique identifiers.

  ## Examples

      Entity.new(:attribute, Attribute)
      |> Entity.identifier(:name)

      Entity.new(:step, Step)
      |> Entity.identifier({:auto, :unique_integer})
  """
  @spec identifier(t(), atom() | {:auto, :unique_integer}) :: t()
  def identifier(%__MODULE__{} = builder, identifier) do
    %{builder | identifier: identifier}
  end

  @doc """
  Sets a transform function to run after the entity is built.

  The transform receives the built struct and can modify or validate it.
  Must return `{:ok, entity}` or `{:error, message}`.

  ## Examples

      Entity.new(:field, Field)
      |> Entity.transform({MyModule, :validate_field, []})
  """
  @spec transform(t(), {module(), atom(), list()}) :: t()
  def transform(%__MODULE__{} = builder, {mod, fun, args} = mfa)
      when is_atom(mod) and is_atom(fun) and is_list(args) do
    %{builder | transform: mfa}
  end

  # ===========================================================================
  # Nested Entities
  # ===========================================================================

  @doc """
  Adds a nested entity under the given key.

  Nested entities appear as children of this entity in the DSL.
  Accepts a built entity, a builder struct, or a function that returns one.

  ## Examples

      # With a built entity
      Entity.new(:form, Form)
      |> Entity.nested_entity(:fields, field_entity)

      # With a builder function
      Entity.new(:form, Form)
      |> Entity.nested_entity(:fields, fn ->
        Entity.new(:field, Field)
        |> Entity.schema([name: [type: :atom]])
        |> Entity.build!()
      end)
  """
  @spec nested_entity(t(), atom(), DslEntity.t() | t() | (-> DslEntity.t() | t())) :: t()
  def nested_entity(%__MODULE__{} = builder, key, entity_or_fun) when is_atom(key) do
    entity = resolve_entity(entity_or_fun)
    existing = Keyword.get(builder.entities, key, [])
    %{builder | entities: Keyword.put(builder.entities, key, existing ++ [entity])}
  end

  @doc """
  Adds multiple nested entities under the given key.

  ## Examples

      Entity.new(:form, Form)
      |> Entity.nested_entities(:fields, [text_field_entity, number_field_entity])
  """
  @spec nested_entities(t(), atom(), [DslEntity.t() | t()]) :: t()
  def nested_entities(%__MODULE__{} = builder, key, entities)
      when is_atom(key) and is_list(entities) do
    resolved = Enum.map(entities, &resolve_entity/1)
    existing = Keyword.get(builder.entities, key, [])
    %{builder | entities: Keyword.put(builder.entities, key, existing ++ resolved)}
  end

  @doc """
  Marks entity keys that should contain only a single value.

  These entities will be validated to have at most one value and
  unwrapped from a list to `nil | single_value`.

  ## Examples

      Entity.new(:resource, Resource)
      |> Entity.nested_entity(:primary_key, pk_entity)
      |> Entity.singleton_entity_keys([:primary_key])
  """
  @spec singleton_entity_keys(t(), [atom()]) :: t()
  def singleton_entity_keys(%__MODULE__{} = builder, keys) when is_list(keys) do
    %{builder | singleton_entity_keys: keys}
  end

  @doc """
  Sets `recursive_as` to allow this entity to nest within itself.

  The key should match an entity key in `entities` where this entity
  can appear recursively.

  ## Examples

      Entity.new(:step, Step)
      |> Entity.recursive_as(:steps)
  """
  @spec recursive_as(t(), atom()) :: t()
  def recursive_as(%__MODULE__{} = builder, key) when is_atom(key) do
    %{builder | recursive_as: key}
  end

  # ===========================================================================
  # Auto-set Fields
  # ===========================================================================

  @doc """
  Sets fields that will be automatically set on the target struct.

  These fields do not need to be in the schema.

  ## Examples

      Entity.new(:special_field, Field)
      |> Entity.auto_set_fields(kind: :special, source: :dsl)
  """
  @spec auto_set_fields(t(), keyword()) :: t()
  def auto_set_fields(%__MODULE__{} = builder, fields) when is_list(fields) do
    %{builder | auto_set_fields: fields}
  end

  @doc """
  Adds a single auto-set field.

  ## Examples

      Entity.new(:field, Field)
      |> Entity.auto_set_field(:internal, true)
  """
  @spec auto_set_field(t(), atom(), any()) :: t()
  def auto_set_field(%__MODULE__{} = builder, key, value) when is_atom(key) do
    %{builder | auto_set_fields: Keyword.put(builder.auto_set_fields, key, value)}
  end

  # ===========================================================================
  # Documentation
  # ===========================================================================

  @doc """
  Sets the description for the entity.

  This will be included in generated documentation.

  ## Examples

      Entity.new(:attribute, Attribute)
      |> Entity.describe("Defines an attribute on the resource")
  """
  @spec describe(t(), String.t()) :: t()
  def describe(%__MODULE__{} = builder, description) when is_binary(description) do
    %{builder | describe: description}
  end

  @doc """
  Sets all examples for the entity documentation.

  ## Examples

      Entity.new(:attribute, Attribute)
      |> Entity.examples([
        "attribute :name, :string",
        "attribute :count, :integer, default: 0"
      ])
  """
  @spec examples(t(), [String.t()]) :: t()
  def examples(%__MODULE__{} = builder, examples) when is_list(examples) do
    %{builder | examples: examples}
  end

  @doc """
  Adds a single example to the entity documentation.

  Prefer `examples/2` when adding multiple examples to avoid repeated list appends.

  ## Examples

      Entity.new(:attribute, Attribute)
      |> Entity.example("attribute :name, :string")
  """
  @spec example(t(), String.t()) :: t()
  def example(%__MODULE__{} = builder, example) when is_binary(example) do
    %{builder | examples: builder.examples ++ [example]}
  end

  @doc """
  Sets the snippet for IDE autocomplete.

  ## Examples

      Entity.new(:attribute, Attribute)
      |> Entity.snippet("attribute :\${1:name}, :\${2:type}")
  """
  @spec snippet(t(), String.t()) :: t()
  def snippet(%__MODULE__{} = builder, snippet) when is_binary(snippet) do
    %{builder | snippet: snippet}
  end

  @doc """
  Sets documentation links.

  ## Examples

      Entity.new(:attribute, Attribute)
      |> Entity.links(guides: ["documentation/attributes.md"])
  """
  @spec links(t(), keyword([String.t()])) :: t()
  def links(%__MODULE__{} = builder, links) when is_list(links) do
    %{builder | links: links}
  end

  @doc """
  Sets deprecation warnings for specific fields.

  ## Examples

      Entity.new(:attribute, Attribute)
      |> Entity.deprecations(old_option: "Use :new_option instead")
  """
  @spec deprecations(t(), keyword(String.t())) :: t()
  def deprecations(%__MODULE__{} = builder, deprecations) when is_list(deprecations) do
    %{builder | deprecations: deprecations}
  end

  # ===========================================================================
  # Modules & Imports
  # ===========================================================================

  @doc """
  Sets modules to import in the entity's DSL scope.

  ## Examples

      Entity.new(:action, Action)
      |> Entity.imports([MyApp.ActionHelpers])
  """
  @spec imports(t(), [module()]) :: t()
  def imports(%__MODULE__{} = builder, imports) when is_list(imports) do
    %{builder | imports: imports}
  end

  @doc """
  Sets schema fields that contain module references (for alias expansion).

  ## Examples

      Entity.new(:change, Change)
      |> Entity.modules([:module])
  """
  @spec modules(t(), [atom()]) :: t()
  def modules(%__MODULE__{} = builder, modules) when is_list(modules) do
    %{builder | modules: modules}
  end

  @doc """
  Sets schema fields with module references that should NOT create dependencies.

  ## Examples

      Entity.new(:change, Change)
      |> Entity.no_depend_modules([:optional_module])
  """
  @spec no_depend_modules(t(), [atom()]) :: t()
  def no_depend_modules(%__MODULE__{} = builder, modules) when is_list(modules) do
    %{builder | no_depend_modules: modules}
  end

  @doc """
  Sets fields to hide from documentation.

  ## Examples

      Entity.new(:attribute, Attribute)
      |> Entity.hide([:internal_field])
  """
  @spec hide(t(), [atom()]) :: t()
  def hide(%__MODULE__{} = builder, fields) when is_list(fields) do
    %{builder | hide: fields}
  end

  # ===========================================================================
  # Build
  # ===========================================================================

  @doc """
  Builds the `%Spark.Dsl.Entity{}` struct.

  Returns `{:ok, entity}` on success or `{:error, reason}` on validation failure.

  ## Validations

    - Name and target are required
    - All args must reference keys in the schema

  ## Examples

      {:ok, entity} = Entity.new(:field, Field)
      |> Entity.schema([name: [type: :atom]])
      |> Entity.build()
  """
  @spec build(t()) :: {:ok, DslEntity.t()} | {:error, String.t()}
  def build(%__MODULE__{} = builder) do
    Helpers.build(builder, DslEntity, [
      fn -> validate_required(builder) end,
      fn -> validate_args(builder) end
    ])
  end

  @doc """
  Builds the `%Spark.Dsl.Entity{}` struct, raising on validation errors.

  ## Examples

      entity = Entity.new(:field, Field)
      |> Entity.schema([name: [type: :atom]])
      |> Entity.build!()
  """
  @spec build!(t()) :: DslEntity.t()
  def build!(%__MODULE__{} = builder) do
    Helpers.build!(builder, DslEntity, "entity", [
      fn -> validate_required(builder) end,
      fn -> validate_args(builder) end
    ])
  end

  
  defp validate_required(%__MODULE__{name: nil}), do: {:error, "Entity name is required"}
  defp validate_required(%__MODULE__{target: nil}), do: {:error, "Entity target is required"}
  defp validate_required(_builder), do: :ok

  defp validate_args(%__MODULE__{args: args, schema: schema}) do
    arg_names =
      Enum.map(args, fn
        {:optional, name} -> name
        {:optional, name, _default} -> name
        name when is_atom(name) -> name
      end)

    schema_keys = Keyword.keys(schema)
    missing = arg_names -- schema_keys

    if missing == [] do
      :ok
    else
      {:error, "Args reference non-existent schema keys: #{inspect(missing)}"}
    end
  end

  defp merge_schema(%__MODULE__{} = builder, entries) do
    %{builder | schema: Keyword.merge(builder.schema, entries)}
  end

  defp resolve_entity(value) do
    Helpers.resolve(value, &build!/1, &match?(%DslEntity{}, &1))
  end
end
