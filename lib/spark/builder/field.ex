# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
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
      iex> Field.new(:name, type: :atom, required?: true, doc: "The field name")
      ...> |> Field.to_spec()
      {:name, [type: :atom, required: true, doc: "The field name"]}

      iex> alias Spark.Builder.Field
      iex> Field.new(:status, type: {:one_of, [:pending, :active]}, default: :pending)
      ...> |> Field.to_spec()
      {:status, [type: {:one_of, [:pending, :active]}, default: :pending]}

  ## Nested Keys

  The `:keys` option accepts either raw keyword lists or `Field` structs,
  allowing composable nested schemas:

      alias Spark.Builder.Field

      Field.new(:config,
        type: :keyword_list,
        keys: [
          Field.new(:host, type: :string, required?: true, doc: "Server hostname"),
          Field.new(:port, type: :integer, default: 4000, doc: "Server port"),
          Field.new(:ssl, type: :boolean, default: false, doc: "Enable SSL")
        ],
        doc: "Server configuration"
      )
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

  Options can set common attributes like `:type`, `:required?`, and `:default`.

  `:keys` accepts a raw schema keyword list or a list of `Field` structs.

  ## Options

    - `:type`, `:required?`, `:required`, `:default`, `:keys`, `:doc`,
      `:type_doc`, `:subsection`, `:as`, `:snippet`, `:links`,
      `:deprecated`, `:rename_to`, `:private?`, `:private`,
      `:hide`, `:type_spec`

  ## Examples

      iex> Spark.Builder.Field.new(:my_field)
      %Spark.Builder.Field{name: :my_field}

      iex> Spark.Builder.Field.new(:type, type: :atom, required?: true)
      ...> |> Spark.Builder.Field.to_spec()
      {:type, [type: :atom, required: true]}
  """
  @spec new(atom()) :: t()
  @spec new(atom(), keyword()) :: t()
  def new(name, opts \\ []) when is_atom(name) and is_list(opts) do
    %__MODULE__{name: name}
    |> apply_opts(opts)
  end

  # ===========================================================================
  # Build
  # ===========================================================================

  @doc """
  Converts the field builder to a schema specification tuple.

  Returns `{name, opts}` suitable for use in a `Spark.Options` schema.

  ## Examples

      iex> Field.new(:name, type: :atom, required?: true)
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
      ...>   Field.new(:name, type: :atom, required?: true),
      ...>   Field.new(:count, type: :integer, default: 0)
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

  defp apply_opts(%__MODULE__{} = field, opts) do
    Enum.reduce(opts, field, fn {key, value}, acc ->
      apply_opt(acc, key, value)
    end)
  end

  defp apply_opt(field, :type, value), do: %{field | type: value}
  defp apply_opt(field, :required, value), do: %{field | required: value}
  defp apply_opt(field, :required?, value), do: %{field | required: value}
  defp apply_opt(field, :default, value), do: %{field | default: value, has_default: true}

  defp apply_opt(field, :keys, value) when is_list(value) do
    normalized = to_schema(value)
    %{field | keys: normalized}
  end

  defp apply_opt(_field, :keys, value), do: raise_invalid_option(:keys, value)

  defp apply_opt(field, :doc, value) when is_binary(value) or value == false do
    %{field | doc: value}
  end

  defp apply_opt(_field, :doc, value), do: raise_invalid_option(:doc, value)

  defp apply_opt(field, :type_doc, value) when is_binary(value) or value == false do
    %{field | type_doc: value}
  end

  defp apply_opt(_field, :type_doc, value), do: raise_invalid_option(:type_doc, value)

  defp apply_opt(field, :subsection, value) when is_binary(value) do
    %{field | subsection: value}
  end

  defp apply_opt(_field, :subsection, value), do: raise_invalid_option(:subsection, value)

  defp apply_opt(field, :links, value) when is_list(value) do
    %{field | links: value}
  end

  defp apply_opt(_field, :links, value), do: raise_invalid_option(:links, value)

  defp apply_opt(field, :as, value) when is_atom(value), do: %{field | as: value}
  defp apply_opt(_field, :as, value), do: raise_invalid_option(:as, value)

  defp apply_opt(field, :snippet, value) when is_binary(value), do: %{field | snippet: value}
  defp apply_opt(_field, :snippet, value), do: raise_invalid_option(:snippet, value)

  defp apply_opt(field, :deprecated, value) when is_binary(value) do
    %{field | deprecated: value}
  end

  defp apply_opt(_field, :deprecated, value), do: raise_invalid_option(:deprecated, value)

  defp apply_opt(field, :rename_to, value) when is_atom(value), do: %{field | rename_to: value}
  defp apply_opt(_field, :rename_to, value), do: raise_invalid_option(:rename_to, value)

  defp apply_opt(field, :private?, value), do: %{field | private?: value}
  defp apply_opt(field, :private, value), do: %{field | private?: value}

  defp apply_opt(field, :hide, value) when is_list(value), do: %{field | hide: value}
  defp apply_opt(_field, :hide, value), do: raise_invalid_option(:hide, value)

  defp apply_opt(field, :type_spec, value), do: %{field | type_spec: value}

  defp apply_opt(_field, key, _value) do
    raise ArgumentError, "Unknown field option: #{inspect(key)}"
  end

  defp raise_invalid_option(key, value) do
    raise ArgumentError, "Invalid value for #{inspect(key)} option: #{inspect(value)}"
  end

  defp maybe_add(acc, _key, value, default) when value == default, do: acc
  defp maybe_add(acc, key, value, _default), do: [{key, value} | acc]

  defp maybe_add_if_present(acc, _key, nil), do: acc
  defp maybe_add_if_present(acc, key, value), do: [{key, value} | acc]

  defp maybe_add_default(acc, %{has_default: false}), do: acc
  defp maybe_add_default(acc, %{has_default: true, default: value}), do: [{:default, value} | acc]
end
