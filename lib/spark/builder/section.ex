# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.Section do
  @moduledoc """
  Builder for constructing `Spark.Dsl.Section` structs.

  This module provides a fluent, pipe-based API for creating DSL section
  definitions programmatically. Sections organize related configurations
  and can contain entities, nested sections, and schema options.

  ## Examples

      alias Spark.Builder.{Section, Entity}

      section = Section.new(:attributes)
        |> Section.describe("Configure resource attributes")
        |> Section.schema([
          primary_key: [type: :boolean, default: true, doc: "Include primary key"]
        ])
        |> Section.entity(attribute_entity)
        |> Section.build!()

  ## Nested Sections

  Sections can contain nested sections:

      Section.new(:resource)
        |> Section.nested_section(fn ->
          Section.new(:attributes)
          |> Section.entity(attribute_entity)
          |> Section.build!()
        end)
        |> Section.build!()
  """

  alias Spark.Builder.Entity, as: EntityBuilder
  alias Spark.Builder.Field
  alias Spark.Builder.Helpers
  alias Spark.Dsl.Entity, as: DslEntity
  alias Spark.Dsl.Section, as: DslSection

  @fields Spark.Dsl.Section.__fields__()

  defstruct @fields

  @type t :: %__MODULE__{
          name: atom() | nil,
          schema: Spark.Options.schema(),
          entities: [DslEntity.t()],
          sections: [DslSection.t()],
          top_level?: boolean(),
          imports: [module()],
          modules: [atom()],
          no_depend_modules: [atom()],
          auto_set_fields: keyword(),
          describe: String.t(),
          snippet: String.t(),
          links: keyword([String.t()]) | nil,
          examples: [String.t()],
          deprecations: keyword(String.t()),
          patchable?: boolean(),
          after_define: {module(), atom(), [any()]} | nil,
          docs: String.t()
        }

  # ===========================================================================
  # Constructor
  # ===========================================================================

  @doc """
  Creates a new section builder with the given name.

  ## Examples

      iex> Section.new(:attributes)
      %Spark.Builder.Section{name: :attributes}
  """
  @spec new(atom()) :: t()
  def new(name) when is_atom(name) do
    %__MODULE__{name: name}
  end

  # ===========================================================================
  # Schema
  # ===========================================================================

  @doc """
  Sets the schema for section-level options.

  Accepts raw `{name, opts}` tuples or `Spark.Builder.Field` structs and
  normalizes them to `Spark.Options` format.

  ## Examples

      Section.new(:resource)
      |> Section.schema([
        generate_primary_key: [type: :boolean, default: true]
      ])
  """
  @spec schema(t(), Spark.Options.schema()) :: t()
  def schema(%__MODULE__{} = builder, schema) when is_list(schema) do
    %{builder | schema: Field.to_schema(schema)}
  end

  @doc """
  Adds a single option to the section schema.

  ## Examples

      Section.new(:resource)
      |> Section.option(:strict, type: :boolean, default: false)
      |> Section.option(:name, type: :atom, required: true)
  """
  @spec option(t(), atom(), keyword()) :: t()
  def option(%__MODULE__{} = builder, name, opts \\ []) when is_atom(name) and is_list(opts) do
    %{builder | schema: Keyword.put(builder.schema, name, opts)}
  end

  # ===========================================================================
  # Entities
  # ===========================================================================

  @doc """
  Adds an entity to the section.

  Accepts a built entity, a builder struct, or a function that returns one.

  ## Examples

      Section.new(:attributes)
      |> Section.entity(attribute_entity)

      Section.new(:attributes)
      |> Section.entity(fn ->
        Entity.new(:attribute, Attribute)
        |> Entity.schema([name: [type: :atom]])
        |> Entity.build!()
      end)
  """
  @spec entity(t(), DslEntity.t() | EntityBuilder.t() | (-> DslEntity.t())) :: t()
  def entity(%__MODULE__{} = builder, entity_or_fun) do
    entity = resolve_entity(entity_or_fun)
    %{builder | entities: builder.entities ++ [entity]}
  end

  @doc """
  Adds multiple entities to the section.

  ## Examples

      Section.new(:fields)
      |> Section.entities([text_field_entity, number_field_entity])
  """
  @spec entities(t(), [DslEntity.t() | EntityBuilder.t()]) :: t()
  def entities(%__MODULE__{} = builder, entities) when is_list(entities) do
    resolved = resolve_entities(entities)
    %{builder | entities: builder.entities ++ resolved}
  end

  # ===========================================================================
  # Nested Sections
  # ===========================================================================

  @doc """
  Adds a nested section.

  Accepts a built section, a builder struct, or a function that returns one.

  ## Examples

      Section.new(:resource)
      |> Section.nested_section(fn ->
        Section.new(:attributes)
        |> Section.entity(attribute_entity)
        |> Section.build!()
      end)
  """
  @spec nested_section(t(), DslSection.t() | t() | (-> DslSection.t())) :: t()
  def nested_section(%__MODULE__{} = builder, section_or_fun) do
    section = resolve_section(section_or_fun)
    %{builder | sections: builder.sections ++ [section]}
  end

  @doc """
  Adds multiple nested sections.

  ## Examples

      Section.new(:resource)
      |> Section.nested_sections([attributes_section, relationships_section])
  """
  @spec nested_sections(t(), [DslSection.t() | t()]) :: t()
  def nested_sections(%__MODULE__{} = builder, sections) when is_list(sections) do
    resolved = resolve_sections(sections)
    %{builder | sections: builder.sections ++ resolved}
  end

  # ===========================================================================
  # Configuration
  # ===========================================================================

  @doc """
  Sets the section as top-level.

  When `true`, the section's DSL can be used directly at module level
  without being wrapped in a `do` block.

  ## Examples

      Section.new(:attributes)
      |> Section.top_level(true)
  """
  @spec top_level(t(), boolean()) :: t()
  def top_level(%__MODULE__{} = builder, top_level? \\ true) do
    %{builder | top_level?: top_level?}
  end

  @doc """
  Sets the section as patchable.

  When `true`, other extensions can add entities to this section via patches.

  ## Examples

      Section.new(:attributes)
      |> Section.patchable(true)
  """
  @spec patchable(t(), boolean()) :: t()
  def patchable(%__MODULE__{} = builder, patchable? \\ true) do
    %{builder | patchable?: patchable?}
  end

  @doc """
  Sets fields that will be automatically set on entities in this section.

  ## Examples

      Section.new(:special_attributes)
      |> Section.auto_set_fields(source: :dsl, internal: true)
  """
  @spec auto_set_fields(t(), keyword()) :: t()
  def auto_set_fields(%__MODULE__{} = builder, fields) when is_list(fields) do
    %{builder | auto_set_fields: fields}
  end

  @doc """
  Sets a callback to run after the section is defined.

  The callback receives the DSL state and can perform additional processing.

  ## Examples

      Section.new(:attributes)
      |> Section.after_define({MyModule, :process_attributes, []})
  """
  @spec after_define(t(), {module(), atom(), [any()]}) :: t()
  def after_define(%__MODULE__{} = builder, {mod, fun, args} = mfa)
      when is_atom(mod) and is_atom(fun) and is_list(args) do
    %{builder | after_define: mfa}
  end

  # ===========================================================================
  # Documentation
  # ===========================================================================

  @doc """
  Sets the description for the section.

  ## Examples

      Section.new(:attributes)
      |> Section.describe("Configure resource attributes")
  """
  @spec describe(t(), String.t()) :: t()
  def describe(%__MODULE__{} = builder, description) when is_binary(description) do
    %{builder | describe: description}
  end

  @doc """
  Sets all examples for the section documentation.

  ## Examples

      Section.new(:attributes)
      |> Section.examples([
        \"\"\"
        attributes do
          attribute :name, :string
        end
        \"\"\"
      ])
  """
  @spec examples(t(), [String.t()]) :: t()
  def examples(%__MODULE__{} = builder, examples) when is_list(examples) do
    %{builder | examples: examples}
  end

  @doc """
  Adds a single example to the section documentation.

  Prefer `examples/2` when adding multiple examples to avoid repeated list appends.

  ## Examples

      Section.new(:attributes)
      |> Section.example("attributes do\\n  attribute :name, :string\\nend")
  """
  @spec example(t(), String.t()) :: t()
  def example(%__MODULE__{} = builder, example) when is_binary(example) do
    %{builder | examples: builder.examples ++ [example]}
  end

  @doc """
  Sets the snippet for IDE autocomplete.

  ## Examples

      Section.new(:attributes)
      |> Section.snippet("attributes do\\n  \${1}\\nend")
  """
  @spec snippet(t(), String.t()) :: t()
  def snippet(%__MODULE__{} = builder, snippet) when is_binary(snippet) do
    %{builder | snippet: snippet}
  end

  @doc """
  Sets documentation links.

  ## Examples

      Section.new(:attributes)
      |> Section.links(guides: ["documentation/attributes.md"])
  """
  @spec links(t(), keyword([String.t()])) :: t()
  def links(%__MODULE__{} = builder, links) when is_list(links) do
    %{builder | links: links}
  end

  @doc """
  Sets deprecation warnings for specific options.

  ## Examples

      Section.new(:resource)
      |> Section.deprecations(old_option: "Use :new_option instead")
  """
  @spec deprecations(t(), keyword(String.t())) :: t()
  def deprecations(%__MODULE__{} = builder, deprecations) when is_list(deprecations) do
    %{builder | deprecations: deprecations}
  end

  # ===========================================================================
  # Modules & Imports
  # ===========================================================================

  @doc """
  Sets modules to import in the section's DSL scope.

  ## Examples

      Section.new(:actions)
      |> Section.imports([MyApp.ActionHelpers])
  """
  @spec imports(t(), [module()]) :: t()
  def imports(%__MODULE__{} = builder, imports) when is_list(imports) do
    %{builder | imports: imports}
  end

  @doc """
  Sets schema fields that contain module references (for alias expansion).

  ## Examples

      Section.new(:resource)
      |> Section.modules([:base_module])
  """
  @spec modules(t(), [atom()]) :: t()
  def modules(%__MODULE__{} = builder, modules) when is_list(modules) do
    %{builder | modules: modules}
  end

  @doc """
  Sets schema fields with module references that should NOT create dependencies.

  ## Examples

      Section.new(:resource)
      |> Section.no_depend_modules([:optional_module])
  """
  @spec no_depend_modules(t(), [atom()]) :: t()
  def no_depend_modules(%__MODULE__{} = builder, modules) when is_list(modules) do
    %{builder | no_depend_modules: modules}
  end

  # ===========================================================================
  # Build
  # ===========================================================================

  @doc """
  Builds the `%Spark.Dsl.Section{}` struct.

  Returns `{:ok, section}` on success or `{:error, reason}` on validation failure.

  ## Examples

      {:ok, section} = Section.new(:fields)
      |> Section.entity(field_entity)
      |> Section.build()
  """
  @spec build(t()) :: {:ok, DslSection.t()} | {:error, String.t()}
  def build(%__MODULE__{} = builder) do
    Helpers.build(builder, DslSection, [
      fn -> validate_required(builder) end
    ])
  end

  @doc """
  Builds the `%Spark.Dsl.Section{}` struct, raising on validation errors.

  ## Examples

      section = Section.new(:fields)
      |> Section.entity(field_entity)
      |> Section.build!()
  """
  @spec build!(t()) :: DslSection.t()
  def build!(%__MODULE__{} = builder) do
    Helpers.build!(builder, DslSection, "section", [
      fn -> validate_required(builder) end
    ])
  end

  # ===========================================================================
  # Private Helpers
  # ===========================================================================

  defp validate_required(%__MODULE__{name: nil}), do: {:error, "name is required"}
  defp validate_required(_builder), do: :ok

  defp resolve_entity(value) do
    Helpers.resolve(value, &EntityBuilder.build!/1, &match?(%DslEntity{}, &1))
  end

  defp resolve_entities(values) do
    Helpers.resolve_list(values, &EntityBuilder.build!/1, &match?(%DslEntity{}, &1))
  end

  defp resolve_section(value) do
    Helpers.resolve(value, &build!/1, &match?(%DslSection{}, &1))
  end

  defp resolve_sections(values) do
    Helpers.resolve_list(values, &build!/1, &match?(%DslSection{}, &1))
  end
end
