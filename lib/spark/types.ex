defmodule Spark.Types do
  @moduledoc "Helpers for spark types"

  def doc_type({:behaviour, _mod}), do: "module"
  def doc_type({:spark, mod}), do: doc_type({:behaviour, mod})
  def doc_type({:spark_behaviour, mod}), do: doc_type({:behaviour, mod})
  def doc_type({:spark_behaviour, mod, _builtins}), do: doc_type({:behaviour, inspect(mod)})
  def doc_type(:module), do: "module"

  def doc_type({:spark_function_behaviour, mod, {_, arity}}) do
    doc_type({:or, [{:fun, arity}, {:spark_behaviour, mod}]})
  end

  def doc_type({:spark_function_behaviour, mod, _builtins, {_, arity}}) do
    doc_type({:or, [{:fun, arity}, {:spark_behaviour, mod}]})
  end

  def doc_type({:custom, _, _, _}), do: "any"
  def doc_type(:any), do: "any"

  def doc_type(:keyword_list), do: "keyword"
  def doc_type(:non_empty_keyword_list), do: "keyword"

  def doc_type({keyword_type, [*: value]})
      when keyword_type in [:keyword_list, :non_empty_keyword_list] and is_list(value),
      do: "keyword(#{doc_type(value[:type])})"

  def doc_type({keyword_type, schema})
      when keyword_type in [:keyword_list, :non_empty_keyword_list] and is_list(schema) do
    options =
      Enum.map_join(schema, ", ", fn {key, value} ->
        "#{key}: #{doc_type(value[:type])}"
      end)

    "[#{options}]"
  end

  def doc_type(:atom), do: "atom"
  def doc_type(:string), do: "String.t"
  def doc_type(:boolean), do: "boolean"
  def doc_type(:integer), do: "integer"
  def doc_type(:non_neg_integer), do: "non_neg_integer"
  def doc_type(:pos_integer), do: "pos_integer"
  def doc_type(:float), do: "float"
  def doc_type(:timeout), do: "timeout"
  def doc_type(:pid), do: "pid"
  def doc_type(:mfa), do: "mfa"
  def doc_type(:mod_arg), do: doc_type({:tuple, [:module, {:list, :any}]})

  def doc_type({:tuple, list}) when is_list(list) do
    tuple = Enum.map_join(list, ", ", &doc_type/1)

    "{#{tuple}}"
  end

  def doc_type(:map), do: "map"

  def doc_type({:map, key_type, value_type}),
    do: "%{optional(#{doc_type(key_type)}) => #{doc_type(value_type)}}"

  def doc_type({:map, schema}) when is_list(schema) do
    options =
      Enum.map_join(schema, ", ", fn {key, value} ->
        "#{if value[:required], do: "required", else: "optional"}(:#{key}) => #{doc_type(value[:type])}"
      end)

    "%{#{options}}"
  end

  def doc_type(:struct), do: "struct"
  def doc_type({:struct, struct}), do: "#{inspect(struct)}"
  def doc_type(nil), do: "nil"
  def doc_type({:fun, 0}), do: "(-> any)"

  def doc_type({:fun, arity}) when is_integer(arity) do
    args =
      Enum.map_join(0..(arity - 1), ", ", fn _ -> "any" end)

    "(#{args} -> any)"
  end

  def doc_type({:fun, args}) when is_list(args) do
    args =
      Enum.map_join(args, ", ", &doc_type/1)

    "(#{args} -> any)"
  end

  def doc_type({:fun, args, return}) when is_list(args) do
    args =
      Enum.map_join(args, ", ", &doc_type/1)

    "(#{args} -> #{doc_type(return)})"
  end

  def doc_type({:one_of, values}), do: doc_type({:in, values})
  def doc_type({:in, values}), do: Enum.map_join(values, " | ", &inspect/1)
  def doc_type({:or, subtypes}), do: Enum.map_join(subtypes, " | ", &doc_type/1)
  def doc_type({:list, subtype}), do: "list(#{doc_type(subtype)})"

  def doc_type({:wrap_list, subtype}) do
    str = doc_type(subtype)
    "#{str} | list(#{str})"
  end

  def doc_type({:list_of, subtype}), do: doc_type({:list, subtype})
  def doc_type({:mfa_or_fun, arity}), do: doc_type({:or, [{:fun, arity}, :mfa]})
  def doc_type(:literal), do: "any"
  def doc_type({:literal, value}), do: inspect(value)
  def doc_type({:tagged_tuple, tag, type}), do: doc_type({:tuple, [{:literal, tag}, type]})
  def doc_type({:spark_type, type, _}), do: doc_type({:behaviour, type})
  def doc_type({:spark_type, type, _, _}), do: doc_type({:behaviour, type})
end
