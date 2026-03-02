# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.Entity do
  @moduledoc """
  Builder for constructing `Spark.Dsl.Entity` structs.

  This module provides an options-based API for creating DSL entity
  definitions programmatically. Entities represent DSL constructors that
  produce struct instances.

  ## Examples

      alias Spark.Builder.Entity

      entity = Entity.new(:attribute, MyApp.Attribute,
        describe: "Defines an attribute on the resource",
        args: [:name, :type],
        schema: [
          name: [type: :atom, required: true, doc: "The attribute name"],
          type: [type: :atom, required: true, doc: "The attribute type"],
          default: [type: :any, doc: "Default value"]
        ],
        identifier: :name,
        examples: ["attribute :email, :string"]
      )
      |> Entity.build!()

  ## Nested Entities

  Entities can contain nested entities via the `:entities` option:

      Entity.new(:field, MyApp.Field,
        entities: [
          children: [
            Entity.new(:validation, MyApp.Validation,
              args: [:type],
              schema: [type: [type: :atom, required: true]]
            )
            |> Entity.build!()
          ]
        ]
      )
      |> Entity.build!()

  ## Accepted Options

    - `:schema` - The schema for entity options
    - `:args` - Positional arguments
    - `:identifier` - Field used for uniqueness validation
    - `:transform` - Transform function as `{module, function, args}`
    - `:entities` - Nested entities as keyword list `[key: [entity, ...]]`
    - `:singleton_entity_keys` - Entity keys that should contain only a single value
    - `:recursive_as` - Key allowing this entity to nest within itself
    - `:auto_set_fields` - Fields automatically set on the target struct
    - `:describe` - Description for documentation
    - `:examples` - List of example strings
    - `:snippet` - IDE autocomplete snippet
    - `:links` - Documentation links
    - `:deprecations` - Deprecation warnings for specific fields
    - `:docs` - Additional documentation
    - `:imports` - Modules to import in the entity's DSL scope
    - `:modules` - Schema fields containing module references
    - `:no_depend_modules` - Module fields that should not create dependencies
    - `:hide` - Fields to hide from documentation
  """
  @moduledoc since: "2.5.0"

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
          identifier: atom() | {:auto, :unique_integer} | nil,
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

  @options_schema [
    schema: [type: {:custom, __MODULE__, :cast_schema, []}, default: []],
    args: [type: {:custom, __MODULE__, :cast_args, []}, default: []],
    entities: [type: {:custom, __MODULE__, :cast_entities, []}, default: []],
    singleton_entity_keys: [type: {:list, :atom}, default: []],
    auto_set_fields: [type: :keyword_list, default: []],
    identifier: [type: {:custom, __MODULE__, :cast_identifier, []}],
    transform: [type: {:custom, __MODULE__, :cast_transform, []}],
    recursive_as: [type: :atom],
    examples: [type: {:list, :string}, default: []],
    describe: [type: :string, default: ""],
    snippet: [type: :string, default: ""],
    links: [type: {:or, [:keyword_list, {:literal, nil}]}],
    hide: [type: {:list, :atom}, default: []],
    deprecations: [type: :keyword_list, default: []],
    docs: [type: :string, default: ""],
    imports: [type: {:list, :atom}, default: []],
    modules: [type: {:list, :atom}, default: []],
    no_depend_modules: [type: {:list, :atom}, default: []]
  ]

  @doc false
  def cast_schema(value) when is_list(value) do
    {:ok, Field.to_schema(value)}
  rescue
    e in ArgumentError -> {:error, Exception.message(e)}
  end

  def cast_schema(value),
    do: {:error, "expected a keyword list for :schema, got: #{inspect(value)}"}

  @doc false
  def cast_args(value) when is_list(value) do
    if Enum.all?(value, fn
         name when is_atom(name) -> true
         {:optional, name} when is_atom(name) -> true
         {:optional, name, _default} when is_atom(name) -> true
         _ -> false
       end) do
      {:ok, value}
    else
      {:error, "each arg must be an atom, {:optional, atom}, or {:optional, atom, default}"}
    end
  end

  def cast_args(value), do: {:error, "expected a list for :args, got: #{inspect(value)}"}

  @doc false
  def cast_entities(value) when is_list(value) do
    {:ok, resolve_entities_keyword(value)}
  rescue
    e in ArgumentError -> {:error, Exception.message(e)}
  end

  def cast_entities(value),
    do: {:error, "expected a keyword list for :entities, got: #{inspect(value)}"}

  @doc false
  def cast_identifier(nil), do: {:ok, nil}
  def cast_identifier({:auto, :unique_integer}), do: {:ok, {:auto, :unique_integer}}
  def cast_identifier(value) when is_atom(value), do: {:ok, value}

  def cast_identifier(value),
    do: {:error, "identifier must be an atom or {:auto, :unique_integer}, got: #{inspect(value)}"}

  @doc false
  def cast_transform(nil), do: {:ok, nil}

  def cast_transform({m, f, a}) when is_atom(m) and is_atom(f) and is_list(a),
    do: {:ok, {m, f, a}}

  def cast_transform(value),
    do: {:error, "transform must be {module, function, args}, got: #{inspect(value)}"}

  @doc """
  Creates a new entity builder with the given name, target struct module, and options.

  ## Parameters

    - `name` - The atom name for the DSL entity (e.g., `:attribute`)
    - `target` - The module of the struct that will be built
    - `opts` - Options to configure the entity (see module docs for accepted options)

  ## Examples

      iex> Entity.new(:attribute, MyApp.Attribute)
      %Spark.Builder.Entity{name: :attribute, target: MyApp.Attribute}

      iex> Entity.new(:attribute, MyApp.Attribute,
      ...>   schema: [name: [type: :atom]],
      ...>   args: [:name]
      ...> )
      %Spark.Builder.Entity{name: :attribute, target: MyApp.Attribute, schema: [name: [type: :atom]], args: [:name]}
  """
  @spec new(atom(), module(), keyword()) :: t()
  def new(name, target, opts \\ []) when is_atom(name) and is_atom(target) and is_list(opts) do
    case Spark.Options.validate(opts, @options_schema) do
      {:ok, validated} ->
        struct!(%__MODULE__{name: name, target: target}, validated)

      {:error, error} ->
        raise ArgumentError, Exception.message(error)
    end
  end

  @doc """
  Builds the `%Spark.Dsl.Entity{}` struct.

  Returns `{:ok, entity}` on success or `{:error, reason}` on validation failure.

  ## Validations

    - Name and target are required
    - All args must reference keys in the schema
    - Identifier must reference a schema or auto_set_fields key (unless schema has `:*`)

  ## Examples

      {:ok, entity} = Entity.new(:field, Field,
        schema: [name: [type: :atom]]
      )
      |> Entity.build()
  """
  @spec build(t()) :: {:ok, DslEntity.t()} | {:error, String.t()}
  def build(%__MODULE__{} = builder) do
    Helpers.build(builder, DslEntity, [
      fn -> validate_required(builder) end,
      fn -> validate_duplicate_args(builder) end,
      fn -> validate_args(builder) end,
      fn -> validate_identifier(builder) end
    ])
  end

  @doc """
  Builds the `%Spark.Dsl.Entity{}` struct, raising on validation errors.

  ## Examples

      entity = Entity.new(:field, Field,
        schema: [name: [type: :atom]]
      )
      |> Entity.build!()
  """
  @spec build!(t()) :: DslEntity.t()
  def build!(%__MODULE__{} = builder) do
    Helpers.build!(builder, DslEntity, "entity", [
      fn -> validate_required(builder) end,
      fn -> validate_duplicate_args(builder) end,
      fn -> validate_args(builder) end,
      fn -> validate_identifier(builder) end
    ])
  end

  # ===========================================================================
  # Private Helpers
  # ===========================================================================

  defp validate_required(%__MODULE__{name: nil}), do: {:error, "name is required"}
  defp validate_required(%__MODULE__{target: nil}), do: {:error, "target is required"}
  defp validate_required(_builder), do: :ok

  defp validate_duplicate_args(%__MODULE__{args: args}) do
    names =
      Enum.map(args, fn
        {:optional, name} -> name
        {:optional, name, _default} -> name
        name when is_atom(name) -> name
      end)

    duplicates = names -- Enum.uniq(names)

    if duplicates == [] do
      :ok
    else
      {:error, "duplicate args: #{inspect(Enum.uniq(duplicates))}"}
    end
  end

  defp validate_args(%__MODULE__{args: args, schema: schema}) do
    if Keyword.has_key?(schema, :*) do
      :ok
    else
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
        {:error, "args reference undefined schema keys: #{inspect(missing)}"}
      end
    end
  end

  defp validate_identifier(%__MODULE__{identifier: nil}), do: :ok

  defp validate_identifier(%__MODULE__{identifier: {:auto, :unique_integer}}), do: :ok

  defp validate_identifier(%__MODULE__{
         identifier: identifier,
         schema: schema,
         auto_set_fields: auto
       })
       when is_atom(identifier) do
    if Keyword.has_key?(schema, :*) do
      :ok
    else
      schema_keys =
        Enum.map(schema, fn {key, opts} ->
          opts[:as] || key
        end)

      auto_keys =
        case auto do
          list when is_list(list) ->
            if Keyword.keyword?(list), do: Keyword.keys(list), else: []

          _ ->
            []
        end

      keys = schema_keys ++ auto_keys

      if identifier in keys do
        :ok
      else
        {:error,
         "identifier references undefined schema or auto_set_fields key: #{inspect(identifier)}"}
      end
    end
  end

  defp resolve_entities(values) do
    Helpers.resolve_list(values, &build!/1, &match?(%DslEntity{}, &1))
  end

  defp resolve_entities_keyword(entities) do
    Enum.map(entities, fn {key, value} ->
      {key, resolve_entities(value)}
    end)
  end
end
