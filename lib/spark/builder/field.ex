# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.Field do
  @moduledoc """
  Builder for individual schema field specifications.

  This module provides a fluent API for constructing field definitions
  used in `Spark.Options` schemas. Each field can have type, validation,
  documentation, and DSL-specific attributes.

  ## Examples

      iex> alias Spark.Builder.Field
      iex> Field.new(:name)
      ...> |> Field.type(:atom)
      ...> |> Field.required()
      ...> |> Field.doc("The field name")
      ...> |> Field.to_spec()
      {:name, [type: :atom, required: true, doc: "The field name"]}

      iex> alias Spark.Builder.{Field, Type}
      iex> Field.new(:status)
      ...> |> Field.type(Type.one_of([:pending, :active]))
      ...> |> Field.default(:pending)
      ...> |> Field.to_spec()
      {:status, [type: {:one_of, [:pending, :active]}, default: :pending]}
  """

  defstruct [
    :name,
    :default,
    :keys,
    :doc,
    :type_doc,
    :subsection,
    :as,
    :snippet,
    :links,
    :deprecated,
    :type_spec,
    :rename_to,
    type: :any,
    required: false,
    private?: false,
    hide: [],
    has_default: false
  ]

  @type t :: %__MODULE__{
          name: atom() | nil,
          type: Spark.Options.type(),
          required: boolean(),
          default: any(),
          has_default: boolean(),
          keys: Spark.Options.schema() | nil,
          doc: String.t() | false | nil,
          type_doc: String.t() | false | nil,
          subsection: String.t() | nil,
          as: atom() | nil,
          snippet: String.t() | nil,
          links: keyword() | nil,
          deprecated: String.t() | nil,
          private?: boolean(),
          hide: [atom()],
          type_spec: Macro.t() | nil,
          rename_to: atom() | nil
        }

  # ===========================================================================
  # Constructor
  # ===========================================================================

  @doc """
  Creates a new field builder with the given name.

  ## Examples

      iex> Spark.Builder.Field.new(:my_field)
      %Spark.Builder.Field{name: :my_field}
  """
  @spec new(atom()) :: t()
  def new(name) when is_atom(name) do
    %__MODULE__{name: name}
  end

  # ===========================================================================
  # Type & Validation
  # ===========================================================================

  @doc """
  Sets the type for this field.

  See `Spark.Options` and `Spark.Builder.Type` for available types.

  ## Examples

      iex> Field.new(:count) |> Field.type(:integer)
      %Spark.Builder.Field{name: :count, type: :integer}
  """
  @spec type(t(), Spark.Options.type()) :: t()
  def type(%__MODULE__{} = field, type) do
    %{field | type: type}
  end

  @doc """
  Marks the field as required.

  ## Examples

      iex> Field.new(:name) |> Field.required()
      %Spark.Builder.Field{name: :name, required: true}

      iex> Field.new(:name) |> Field.required(false)
      %Spark.Builder.Field{name: :name, required: false}
  """
  @spec required(t(), boolean()) :: t()
  def required(%__MODULE__{} = field, required? \\ true) do
    %{field | required: required?}
  end

  @doc """
  Sets the default value for this field.

  ## Examples

      iex> Field.new(:count) |> Field.default(0)
      %Spark.Builder.Field{name: :count, default: 0, has_default: true}
  """
  @spec default(t(), any()) :: t()
  def default(%__MODULE__{} = field, value) do
    %{field | default: value, has_default: true}
  end

  @doc """
  Sets nested keys for keyword_list, non_empty_keyword_list, or map types.

  Accepts either a raw schema keyword list or a list of Field structs.
  Invalid entries raise an `ArgumentError`.

  ## Examples

      iex> Field.new(:config)
      ...> |> Field.type(:keyword_list)
      ...> |> Field.keys([host: [type: :string], port: [type: :integer]])

      iex> Field.new(:config)
      ...> |> Field.type(:keyword_list)
      ...> |> Field.keys([
      ...>   Field.new(:host) |> Field.type(:string),
      ...>   Field.new(:port) |> Field.type(:integer)
      ...> ])
  """
  @spec keys(t(), Spark.Options.schema() | [t()]) :: t()
  def keys(%__MODULE__{} = field, schema) when is_list(schema) do
    normalized = to_schema(schema)
    %{field | keys: normalized}
  end

  # ===========================================================================
  # Documentation
  # ===========================================================================

  @doc """
  Sets the documentation string for this field.

  Pass `false` to explicitly hide from documentation.

  ## Examples

      iex> Field.new(:name) |> Field.doc("The entity name")
  """
  @spec doc(t(), String.t() | false) :: t()
  def doc(%__MODULE__{} = field, doc) when is_binary(doc) or doc == false do
    %{field | doc: doc}
  end

  @doc """
  Sets custom type documentation.

  Pass `false` to omit type from documentation.

  ## Examples

      iex> Field.new(:handler) |> Field.type_doc("A function or MFA tuple")
  """
  @spec type_doc(t(), String.t() | false) :: t()
  def type_doc(%__MODULE__{} = field, type_doc) when is_binary(type_doc) or type_doc == false do
    %{field | type_doc: type_doc}
  end

  @doc """
  Sets the subsection for documentation grouping.

  ## Examples

      iex> Field.new(:timeout) |> Field.subsection("Advanced Options")
  """
  @spec subsection(t(), String.t()) :: t()
  def subsection(%__MODULE__{} = field, subsection) when is_binary(subsection) do
    %{field | subsection: subsection}
  end

  @doc """
  Sets documentation links.

  ## Examples

      iex> Field.new(:type) |> Field.links(guides: ["documentation/types.md"])
  """
  @spec links(t(), keyword()) :: t()
  def links(%__MODULE__{} = field, links) when is_list(links) do
    %{field | links: links}
  end

  # ===========================================================================
  # DSL Support
  # ===========================================================================

  @doc """
  Sets an alias name for DSL usage.

  The field will be stored under its original name but can be set
  using the alias in the DSL.

  ## Examples

      iex> Field.new(:source_field) |> Field.as(:source)
  """
  @spec as(t(), atom()) :: t()
  def as(%__MODULE__{} = field, name) when is_atom(name) do
    %{field | as: name}
  end

  @doc """
  Sets the snippet for IDE autocomplete.

  ## Examples

      iex> Field.new(:handler) |> Field.snippet("fn ${1:arg} -> ${2:body} end")
  """
  @spec snippet(t(), String.t()) :: t()
  def snippet(%__MODULE__{} = field, snippet) when is_binary(snippet) do
    %{field | snippet: snippet}
  end

  @doc """
  Marks the field as deprecated with a message.

  ## Examples

      iex> Field.new(:old_option) |> Field.deprecated("Use :new_option instead")
  """
  @spec deprecated(t(), String.t()) :: t()
  def deprecated(%__MODULE__{} = field, message) when is_binary(message) do
    %{field | deprecated: message}
  end

  @doc """
  Renames the field to a different key after validation.

  ## Examples

      iex> Field.new(:old_name) |> Field.rename_to(:new_name)
  """
  @spec rename_to(t(), atom()) :: t()
  def rename_to(%__MODULE__{} = field, name) when is_atom(name) do
    %{field | rename_to: name}
  end

  # ===========================================================================
  # Metadata
  # ===========================================================================

  @doc """
  Marks the field as private (hidden from documentation and validators).

  ## Examples

      iex> Field.new(:internal) |> Field.private()
  """
  @spec private(t(), boolean()) :: t()
  def private(%__MODULE__{} = field, private? \\ true) do
    %{field | private?: private?}
  end

  @doc """
  Sets contexts where the field should be hidden from documentation.

  ## Examples

      iex> Field.new(:internal) |> Field.hide([:docs, :schema])
  """
  @spec hide(t(), [atom()]) :: t()
  def hide(%__MODULE__{} = field, contexts) when is_list(contexts) do
    %{field | hide: contexts}
  end

  @doc """
  Sets a custom typespec for the field.

  ## Examples

      iex> Field.new(:data) |> Field.type_spec(quote do: map())
  """
  @spec type_spec(t(), Macro.t()) :: t()
  def type_spec(%__MODULE__{} = field, spec) do
    %{field | type_spec: spec}
  end

  # ===========================================================================
  # Build
  # ===========================================================================

  @doc """
  Converts the field builder to a schema specification tuple.

  Returns `{name, opts}` suitable for use in a `Spark.Options` schema.

  ## Examples

      iex> Field.new(:name)
      ...> |> Field.type(:atom)
      ...> |> Field.required()
      ...> |> Field.to_spec()
      {:name, [type: :atom, required: true]}
  """
  @spec to_spec(t()) :: {atom(), keyword()}
  def to_spec(%__MODULE__{name: name} = field) when is_atom(name) do
    opts =
      []
      |> maybe_add(:type, field.type, :any)
      |> maybe_add(:required, field.required, false)
      |> maybe_add_default(field)
      |> maybe_add_if_present(:keys, field.keys)
      |> maybe_add_if_present(:doc, field.doc)
      |> maybe_add_if_present(:type_doc, field.type_doc)
      |> maybe_add_if_present(:subsection, field.subsection)
      |> maybe_add_if_present(:as, field.as)
      |> maybe_add_if_present(:snippet, field.snippet)
      |> maybe_add_if_present(:links, field.links)
      |> maybe_add_if_present(:deprecated, field.deprecated)
      |> maybe_add(:private?, field.private?, false)
      |> maybe_add(:hide, field.hide, [])
      |> maybe_add_if_present(:type_spec, field.type_spec)
      |> maybe_add_if_present(:rename_to, field.rename_to)
      |> Enum.reverse()

    {name, opts}
  end

  @doc """
  Builds a complete schema from a list of field builders or raw schema tuples.

  ## Examples

      iex> [
      ...>   Field.new(:name) |> Field.type(:atom) |> Field.required(),
      ...>   Field.new(:count) |> Field.type(:integer) |> Field.default(0)
      ...> ]
      ...> |> Field.to_schema()
      [name: [type: :atom, required: true], count: [type: :integer, default: 0]]

      iex> Field.to_schema([name: [type: :atom, required: true]])
      [name: [type: :atom, required: true]]
  """
  @spec to_schema([t() | {atom(), keyword()}] | t()) :: Spark.Options.schema()
  def to_schema(%__MODULE__{} = field), do: to_schema([field])

  def to_schema(fields) when is_list(fields) do
    Enum.map(fields, fn
      %__MODULE__{} = field -> to_spec(field)
      {key, opts} when is_atom(key) and is_list(opts) -> {key, opts}
      other -> raise ArgumentError, "Invalid field specification: #{inspect(other)}"
    end)
  end

  defp maybe_add(acc, _key, value, default) when value == default, do: acc
  defp maybe_add(acc, key, value, _default), do: [{key, value} | acc]

  defp maybe_add_if_present(acc, _key, nil), do: acc
  defp maybe_add_if_present(acc, key, value), do: [{key, value} | acc]

  defp maybe_add_default(acc, %{has_default: false}), do: acc
  defp maybe_add_default(acc, %{has_default: true, default: value}), do: [{:default, value} | acc]
end
