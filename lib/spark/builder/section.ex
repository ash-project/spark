# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.Section do
  @moduledoc """
  Builder for constructing `Spark.Dsl.Section` structs.

  This module provides an options-based API for creating DSL section
  definitions programmatically. Sections organize related configurations
  and can contain entities, nested sections, and schema options.

  ## Examples

      alias Spark.Builder.{Section, Entity}

      section = Section.new(:attributes,
        describe: "Configure resource attributes",
        schema: [
          primary_key: [type: :boolean, default: true, doc: "Include primary key"]
        ],
        entities: [attribute_entity]
      )
      |> Section.build!()

  ## Nested Sections

  Sections can contain nested sections via the `:sections` option:

      Section.new(:resource,
        sections: [
          Section.new(:attributes,
            entities: [attribute_entity]
          )
          |> Section.build!()
        ]
      )
      |> Section.build!()

  ## Accepted Options

    - `:schema` - Schema for section-level options
    - `:entities` - List of entities in this section
    - `:sections` - List of nested sections
    - `:top_level?` - Whether the section can be used at module level without a `do` block
    - `:patchable?` - Whether other extensions can add entities via patches
    - `:auto_set_fields` - Fields automatically set on entities in this section
    - `:after_define` - Callback to run after the section is defined as `{module, function}`
    - `:describe` - Description for documentation
    - `:examples` - List of example strings
    - `:snippet` - IDE autocomplete snippet
    - `:links` - Documentation links
    - `:deprecations` - Deprecation warnings for specific options
    - `:docs` - Additional documentation
    - `:imports` - Modules to import in the section's DSL scope
    - `:modules` - Schema fields containing module references
    - `:no_depend_modules` - Module fields that should not create dependencies
  """
  @moduledoc since: "2.5.0"

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
          after_define: {module(), atom()} | nil,
          docs: String.t()
        }

  @doc """
  Creates a new section builder with the given name and options.

  ## Parameters

    - `name` - The atom name for the DSL section (e.g., `:attributes`)
    - `opts` - Options to configure the section (see module docs for accepted options)

  ## Examples

      iex> Section.new(:attributes)
      %Spark.Builder.Section{name: :attributes}

      iex> Section.new(:attributes,
      ...>   describe: "Resource attributes",
      ...>   top_level?: true
      ...> )
      %Spark.Builder.Section{name: :attributes, describe: "Resource attributes", top_level?: true}
  """
  @spec new(atom(), keyword()) :: t()
  def new(name, opts \\ []) when is_atom(name) and is_list(opts) do
    {schema, opts} = Keyword.pop(opts, :schema, [])
    {entities, opts} = Keyword.pop(opts, :entities, [])
    {sections, opts} = Keyword.pop(opts, :sections, [])

    base = %__MODULE__{name: name}

    builder =
      Enum.reduce(opts, base, fn {key, value}, acc ->
        Map.put(acc, key, value)
      end)

    builder = %{builder | schema: Field.to_schema(schema)}
    builder = %{builder | entities: resolve_entities(entities)}
    %{builder | sections: resolve_sections(sections)}
  end

  @doc """
  Builds the `%Spark.Dsl.Section{}` struct.

  Returns `{:ok, section}` on success or `{:error, reason}` on validation failure.

  ## Examples

      {:ok, section} = Section.new(:fields,
        entities: [field_entity]
      )
      |> Section.build()
  """
  @spec build(t()) :: {:ok, DslSection.t()} | {:error, String.t()}
  def build(%__MODULE__{} = builder) do
    Helpers.build(builder, DslSection, [
      fn -> validate_required(builder) end,
      fn -> validate_known_keys(builder) end,
      fn -> validate_after_define(builder) end
    ])
  end

  @doc """
  Builds the `%Spark.Dsl.Section{}` struct, raising on validation errors.

  ## Examples

      section = Section.new(:fields,
        entities: [field_entity]
      )
      |> Section.build!()
  """
  @spec build!(t()) :: DslSection.t()
  def build!(%__MODULE__{} = builder) do
    Helpers.build!(builder, DslSection, "section", [
      fn -> validate_required(builder) end,
      fn -> validate_known_keys(builder) end,
      fn -> validate_after_define(builder) end
    ])
  end

  # ===========================================================================
  # Private Helpers
  # ===========================================================================

  defp validate_required(%__MODULE__{name: nil}), do: {:error, "name is required"}
  defp validate_required(_builder), do: :ok

  defp validate_known_keys(%__MODULE__{} = builder) do
    known = MapSet.new(DslSection.__field_names__())

    unknown =
      builder
      |> Map.from_struct()
      |> Map.keys()
      |> Enum.reject(&MapSet.member?(known, &1))
      |> Enum.sort()

    if unknown == [] do
      :ok
    else
      {:error, "unknown options: #{inspect(unknown)}"}
    end
  end

  defp validate_after_define(%__MODULE__{after_define: nil}), do: :ok

  defp validate_after_define(%__MODULE__{after_define: {module, function}})
       when is_atom(module) and is_atom(function),
       do: :ok

  defp validate_after_define(%__MODULE__{after_define: value}) do
    {:error, "after_define must be {module, function}, got: #{inspect(value)}"}
  end

  defp resolve_entities(values) do
    Helpers.resolve_list(values, &EntityBuilder.build!/1, &match?(%DslEntity{}, &1))
  end

  defp resolve_sections(values) do
    Helpers.resolve_list(values, &build!/1, &match?(%DslSection{}, &1))
  end
end
