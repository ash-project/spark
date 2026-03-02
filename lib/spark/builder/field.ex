# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.Field do
  @moduledoc """
  Builder for individual schema field specifications.

  This module provides an option-based API for constructing field definitions
  used in `Spark.Options` schemas. Each field can have type, validation,
  documentation, and DSL-specific attributes.

  ## Examples

      iex> alias Spark.Builder.Field
      iex> Field.new(:name, :atom, required: true, doc: "The field name")
      ...> |> Field.to_spec()
      {:name, [type: :atom, required: true, doc: "The field name"]}

      iex> alias Spark.Builder.Field
      iex> Field.new(:status, {:one_of, [:pending, :active]}, default: :pending)
      ...> |> Field.to_spec()
      {:status, [type: {:one_of, [:pending, :active]}, default: :pending]}

  ## Nested Keys

  The `:keys` option accepts raw keyword lists, `Field` structs, or a
  zero-arity function returning a schema, allowing composable nested schemas:

      alias Spark.Builder.Field

      Field.new(:config, :keyword_list,
        keys: [
          Field.new(:host, :string, required: true, doc: "Server hostname"),
          Field.new(:port, :integer, default: 4000, doc: "Server port"),
          Field.new(:ssl, :boolean, default: false, doc: "Enable SSL")
        ],
        doc: "Server configuration"
      )

  Lazy schemas are supported:

      Field.new(:config, :keyword_list,
        keys: &__MODULE__.options_schema/0
      )
  """
  @moduledoc since: "2.5.0"

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
          keys: Spark.Options.schema() | (-> Spark.Options.schema()) | nil,
          doc: String.t() | false | nil,
          type_doc: String.t() | false | nil,
          subsection: String.t() | nil,
          as: atom() | nil,
          snippet: String.t() | nil,
          links: keyword() | nil,
          deprecated: String.t() | nil,
          private?: boolean(),
          hide: [atom()],
          type_spec: Macro.t() | nil
        }

  # ===========================================================================
  # Constructor
  # ===========================================================================

  @options_schema [
    required: [type: :boolean],
    default: [type: :any],
    keys: [type: {:custom, __MODULE__, :cast_keys, []}],
    doc: [type: {:or, [:string, {:literal, false}]}],
    type_doc: [type: {:or, [:string, {:literal, false}]}],
    subsection: [type: :string],
    as: [type: :atom],
    snippet: [type: :string],
    links: [type: :keyword_list],
    deprecated: [type: :string],
    private?: [type: :boolean],
    hide: [type: {:list, :atom}],
    type_spec: [type: :any]
  ]

  @doc false
  def cast_keys(value) when is_list(value) do
    {:ok, to_schema(value)}
  rescue
    e in ArgumentError -> {:error, Exception.message(e)}
  end

  def cast_keys(value) when is_function(value), do: {:ok, value}

  def cast_keys(value),
    do: {:error, "expected a keyword list or function for :keys, got: #{inspect(value)}"}

  @doc """
  Creates a new field builder with the given name and type.

  Options can set common attributes like `:required` and `:default`.

  `:keys` accepts a raw schema keyword list, a list of `Field` structs, or a
  zero-arity function that returns a schema.

  ## Options

    - `:required`, `:default`, `:keys`, `:doc`, `:type_doc`,
      `:subsection`, `:as`, `:snippet`, `:links`, `:deprecated`,
      `:private?`, `:hide`, `:type_spec`

  ## Examples

      iex> Spark.Builder.Field.new(:my_field, :any)
      %Spark.Builder.Field{name: :my_field, type: :any}

      iex> Spark.Builder.Field.new(:type, :atom, required: true)
      ...> |> Spark.Builder.Field.to_spec()
      {:type, [type: :atom, required: true]}
  """
  @spec new(atom(), Spark.Options.type()) :: t()
  @spec new(atom(), Spark.Options.type(), keyword()) :: t()
  def new(name, type, opts \\ []) when is_atom(name) and is_list(opts) do
    case Spark.Options.validate(opts, @options_schema) do
      {:ok, validated} ->
        has_default = Keyword.has_key?(validated, :default)

        %__MODULE__{name: name, type: type, has_default: has_default}
        |> struct!(validated)

      {:error, error} ->
        raise ArgumentError, Exception.message(error)
    end
  end

  # ===========================================================================
  # Build
  # ===========================================================================

  @doc """
  Converts the field builder to a schema specification tuple.

  Returns `{name, opts}` suitable for use in a `Spark.Options` schema.

  ## Examples

      iex> Field.new(:name, :atom, required: true)
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
      |> Enum.reverse()

    {name, opts}
  end

  @doc """
  Builds a complete schema from a list of field builders or raw schema tuples.

  ## Examples

      iex> [
      ...>   Field.new(:name, :atom, required: true),
      ...>   Field.new(:count, :integer, default: 0)
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
