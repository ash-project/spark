# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.Type do
  @moduledoc """
  Helper functions for constructing Spark.Options type expressions.

  This module provides a fluent API for building type specifications
  used in schema definitions. All functions return raw values (atoms or tuples)
  that are directly usable with `Spark.Options`.

  ## Examples

      iex> Spark.Builder.Type.atom()
      :atom

      iex> Spark.Builder.Type.list(Spark.Builder.Type.string())
      {:list, :string}

      iex> Spark.Builder.Type.or_types([:atom, :string])
      {:or, [:atom, :string]}

      iex> Spark.Builder.Type.one_of([:pending, :active, :completed])
      {:one_of, [:pending, :active, :completed]}
  """

  # ===========================================================================
  # Basic Types
  # ===========================================================================

  @doc "Any type - accepts any value."
  @spec any() :: :any
  def any, do: :any

  @doc "Atom type."
  @spec atom() :: :atom
  def atom, do: :atom

  @doc "String type."
  @spec string() :: :string
  def string, do: :string

  @doc "Boolean type."
  @spec boolean() :: :boolean
  def boolean, do: :boolean

  @doc "Integer type."
  @spec integer() :: :integer
  def integer, do: :integer

  @doc "Non-negative integer (>= 0)."
  @spec non_neg_integer() :: :non_neg_integer
  def non_neg_integer, do: :non_neg_integer

  @doc "Positive integer (> 0)."
  @spec pos_integer() :: :pos_integer
  def pos_integer, do: :pos_integer

  @doc "Float type."
  @spec float() :: :float
  def float, do: :float

  @doc "Number type (integer or float)."
  @spec number() :: :number
  def number, do: :number

  @doc "Timeout type (non-negative integer or :infinity)."
  @spec timeout() :: :timeout
  def timeout, do: :timeout

  @doc "PID type."
  @spec pid() :: :pid
  def pid, do: :pid

  @doc "Reference type."
  @spec reference() :: :reference
  def reference, do: :reference

  @doc "Module type (atom representing a module)."
  @spec module() :: :module
  def module, do: :module

  @doc "MFA tuple type ({module, function, args})."
  @spec mfa() :: :mfa
  def mfa, do: :mfa

  @doc "Module with arguments tuple ({module, args})."
  @spec mod_arg() :: :mod_arg
  def mod_arg, do: :mod_arg

  @doc "Compiled regex type."
  @spec regex() :: :regex
  def regex, do: :regex

  @doc "Regex stored as MFA for caching (OTP 28+ compatible)."
  @spec regex_as_mfa() :: :regex_as_mfa
  def regex_as_mfa, do: :regex_as_mfa

  @doc "Literal value type."
  @spec literal() :: :literal
  def literal, do: :literal

  @doc "Quoted code type (retains AST)."
  @spec quoted() :: :quoted
  def quoted, do: :quoted

  @doc "Any struct type."
  @spec struct() :: :struct
  def struct, do: :struct

  @doc "Any function type."
  @spec fun() :: :fun
  def fun, do: :fun

  @doc "Keyword list type."
  @spec keyword_list() :: :keyword_list
  def keyword_list, do: :keyword_list

  @doc "Non-empty keyword list type."
  @spec non_empty_keyword_list() :: :non_empty_keyword_list
  def non_empty_keyword_list, do: :non_empty_keyword_list

  @doc "Map type (with atom keys)."
  @spec map() :: :map
  def map, do: :map

  # ===========================================================================
  # Parameterized Types
  # ===========================================================================

  @doc """
  Function with specific arity.

  ## Examples

      iex> Spark.Builder.Type.fun(1)
      {:fun, 1}

      iex> Spark.Builder.Type.fun(2)
      {:fun, 2}
  """
  @spec fun(non_neg_integer()) :: {:fun, non_neg_integer()}
  def fun(arity) when is_integer(arity) and arity >= 0 do
    {:fun, arity}
  end

  @doc """
  Function with typed arguments and return type.

  ## Examples

      iex> Spark.Builder.Type.fun([:atom, :string], :boolean)
      {:fun, [:atom, :string], :boolean}
  """
  @spec fun(list(), Spark.Options.type()) :: {:fun, list(), Spark.Options.type()}
  def fun(arg_types, return_type) when is_list(arg_types) do
    {:fun, arg_types, return_type}
  end

  @doc """
  List of values with a specific element type.

  ## Examples

      iex> Spark.Builder.Type.list(:atom)
      {:list, :atom}

      iex> Spark.Builder.Type.list(Spark.Builder.Type.string())
      {:list, :string}
  """
  @spec list(Spark.Options.type()) :: {:list, Spark.Options.type()}
  def list(element_type) do
    {:list, element_type}
  end

  @doc """
  Wraps a single value in a list, or accepts a list directly.

  ## Examples

      iex> Spark.Builder.Type.wrap_list(:atom)
      {:wrap_list, :atom}
  """
  @spec wrap_list(Spark.Options.type()) :: {:wrap_list, Spark.Options.type()}
  def wrap_list(element_type) do
    {:wrap_list, element_type}
  end

  @doc """
  Tuple with typed elements.

  ## Examples

      iex> Spark.Builder.Type.tuple([:atom, :string])
      {:tuple, [:atom, :string]}
  """
  @spec tuple(list(Spark.Options.type())) :: {:tuple, list()}
  def tuple(element_types) when is_list(element_types) do
    {:tuple, element_types}
  end

  @doc """
  Map with typed keys and values.

  ## Examples

      iex> Spark.Builder.Type.map(:atom, :any)
      {:map, :atom, :any}

      iex> Spark.Builder.Type.map(:string, :integer)
      {:map, :string, :integer}
  """
  @spec map(Spark.Options.type(), Spark.Options.type()) ::
          {:map, Spark.Options.type(), Spark.Options.type()}
  def map(key_type, value_type) do
    {:map, key_type, value_type}
  end

  @doc """
  Specific struct type.

  ## Examples

      iex> Spark.Builder.Type.struct(MyStruct)
      {:struct, MyStruct}
  """
  @spec struct(module()) :: {:struct, module()}
  def struct(module) when is_atom(module) do
    {:struct, module}
  end

  @doc """
  Exact literal value.

  ## Examples

      iex> Spark.Builder.Type.literal(:specific_value)
      {:literal, :specific_value}
  """
  @spec literal(any()) :: {:literal, any()}
  def literal(value) do
    {:literal, value}
  end

  @doc """
  Keyword list with a nested schema.

  ## Examples

      iex> Spark.Builder.Type.keyword_list([host: [type: :string], port: [type: :integer]])
      {:keyword_list, [host: [type: :string], port: [type: :integer]]}
  """
  @spec keyword_list(Spark.Options.schema()) :: {:keyword_list, Spark.Options.schema()}
  def keyword_list(schema) when is_list(schema) do
    {:keyword_list, schema}
  end

  @doc """
  Non-empty keyword list with a nested schema.

  ## Examples

      iex> Spark.Builder.Type.non_empty_keyword_list([name: [type: :atom, required: true]])
      {:non_empty_keyword_list, [name: [type: :atom, required: true]]}
  """
  @spec non_empty_keyword_list(Spark.Options.schema()) ::
          {:non_empty_keyword_list, Spark.Options.schema()}
  def non_empty_keyword_list(schema) when is_list(schema) do
    {:non_empty_keyword_list, schema}
  end

  @doc """
  Map with a nested schema (atom keys).

  ## Examples

      iex> Spark.Builder.Type.map([name: [type: :string]])
      {:map, [name: [type: :string]]}
  """
  @spec map(Spark.Options.schema()) :: {:map, Spark.Options.schema()}
  def map(schema) when is_list(schema) do
    {:map, schema}
  end

  # ===========================================================================
  # Choice Types
  # ===========================================================================

  @doc """
  Value must be one of the given choices (list or range).

  ## Examples

      iex> Spark.Builder.Type.in_choices([:pending, :active, :completed])
      {:in, [:pending, :active, :completed]}

      iex> Spark.Builder.Type.in_choices(1..10)
      {:in, 1..10}
  """
  @spec in_choices(list() | Range.t()) :: {:in, list() | Range.t()}
  def in_choices(choices) do
    {:in, choices}
  end

  @doc """
  Value must be one of the given choices (alias for `in_choices/1`).

  ## Examples

      iex> Spark.Builder.Type.one_of([:read, :write, :delete])
      {:one_of, [:read, :write, :delete]}
  """
  @spec one_of(list() | Range.t()) :: {:one_of, list() | Range.t()}
  def one_of(choices) do
    {:one_of, choices}
  end

  @doc """
  Tagged tuple with a specific tag atom and inner type.

  ## Examples

      iex> Spark.Builder.Type.tagged_tuple(:ok, :any)
      {:tagged_tuple, :ok, :any}
  """
  @spec tagged_tuple(atom(), Spark.Options.type()) ::
          {:tagged_tuple, atom(), Spark.Options.type()}
  def tagged_tuple(tag, inner_type) when is_atom(tag) do
    {:tagged_tuple, tag, inner_type}
  end

  # ===========================================================================
  # Combinators
  # ===========================================================================

  @doc """
  Value must match one of the given types.

  ## Examples

      iex> Spark.Builder.Type.or_types([:atom, :string])
      {:or, [:atom, :string]}

      iex> Spark.Builder.Type.or_types([{:list, :atom}, :atom])
      {:or, [{:list, :atom}, :atom]}
  """
  @spec or_types(list(Spark.Options.type())) :: {:or, list()}
  def or_types(subtypes) when is_list(subtypes) do
    {:or, subtypes}
  end

  @doc """
  Value must match all of the given types (with value transformation).

  ## Examples

      iex> Spark.Builder.Type.and_types([:atom, {:in, [:foo, :bar]}])
      {:and, [:atom, {:in, [:foo, :bar]}]}
  """
  @spec and_types(list(Spark.Options.type())) :: {:and, list()}
  def and_types(subtypes) when is_list(subtypes) do
    {:and, subtypes}
  end

  # ===========================================================================
  # Custom Validation
  # ===========================================================================

  @doc """
  Custom validation function.

  The function receives the value and must return `{:ok, value}` or `{:error, message}`.

  ## Examples

      iex> Spark.Builder.Type.custom(MyValidator, :validate, [])
      {:custom, MyValidator, :validate, []}

      iex> Spark.Builder.Type.custom(MyValidator, :validate_with_opts, [:strict])
      {:custom, MyValidator, :validate_with_opts, [:strict]}
  """
  @spec custom(module(), atom(), list()) :: {:custom, module(), atom(), list()}
  def custom(module, function, args \\ [])
      when is_atom(module) and is_atom(function) and is_list(args) do
    {:custom, module, function, args}
  end

  @doc """
  MFA or function with specific arity.

  ## Examples

      iex> Spark.Builder.Type.mfa_or_fun(1)
      {:mfa_or_fun, 1}
  """
  @spec mfa_or_fun(non_neg_integer()) :: {:mfa_or_fun, non_neg_integer()}
  def mfa_or_fun(arity) when is_integer(arity) and arity >= 0 do
    {:mfa_or_fun, arity}
  end

  # ===========================================================================
  # Spark-Specific Types
  # ===========================================================================

  @doc """
  Module that uses a Spark DSL.

  ## Examples

      iex> Spark.Builder.Type.spark(Ash.Resource)
      {:spark, Ash.Resource}
  """
  @spec spark(module()) :: {:spark, module()}
  def spark(dsl_module) when is_atom(dsl_module) do
    {:spark, dsl_module}
  end

  @doc """
  Module implementing a behaviour.

  ## Examples

      iex> Spark.Builder.Type.behaviour(GenServer)
      {:behaviour, GenServer}
  """
  @spec behaviour(module()) :: {:behaviour, module()}
  def behaviour(module) when is_atom(module) do
    {:behaviour, module}
  end

  @doc """
  Module implementing a protocol.

  ## Examples

      iex> Spark.Builder.Type.protocol(Enumerable)
      {:protocol, Enumerable}
  """
  @spec protocol(module()) :: {:protocol, module()}
  def protocol(module) when is_atom(module) do
    {:protocol, module}
  end

  @doc """
  Protocol implementation.

  ## Examples

      iex> Spark.Builder.Type.impl(String.Chars)
      {:impl, String.Chars}
  """
  @spec impl(module()) :: {:impl, module()}
  def impl(module) when is_atom(module) do
    {:impl, module}
  end

  @doc """
  Spark behaviour (module implementing the behaviour with ElixirSense support).

  ## Examples

      iex> Spark.Builder.Type.spark_behaviour(MyBehaviour)
      {:spark_behaviour, MyBehaviour}
  """
  @spec spark_behaviour(module()) :: {:spark_behaviour, module()}
  def spark_behaviour(module) when is_atom(module) do
    {:spark_behaviour, module}
  end

  @doc """
  Spark behaviour with builtin module for ElixirSense.

  ## Examples

      iex> Spark.Builder.Type.spark_behaviour(MyBehaviour, MyBuiltins)
      {:spark_behaviour, MyBehaviour, MyBuiltins}
  """
  @spec spark_behaviour(module(), module()) :: {:spark_behaviour, module(), module()}
  def spark_behaviour(module, builtin) when is_atom(module) and is_atom(builtin) do
    {:spark_behaviour, module, builtin}
  end

  @doc """
  Spark function behaviour (module or function).

  ## Examples

      iex> Spark.Builder.Type.spark_function_behaviour(MyBehaviour, {MyBehaviour.Function, 1})
      {:spark_function_behaviour, MyBehaviour, {MyBehaviour.Function, 1}}
  """
  @spec spark_function_behaviour(module(), {module(), non_neg_integer()}) ::
          {:spark_function_behaviour, module(), {module(), non_neg_integer()}}
  def spark_function_behaviour(behaviour, {function_mod, arity})
      when is_atom(behaviour) and is_atom(function_mod) and is_integer(arity) and arity >= 0 do
    {:spark_function_behaviour, behaviour, {function_mod, arity}}
  end

  @doc """
  Spark function behaviour with builtin module.

  ## Examples

      iex> Spark.Builder.Type.spark_function_behaviour(MyBehaviour, MyBuiltins, {MyBehaviour.Function, 1})
      {:spark_function_behaviour, MyBehaviour, MyBuiltins, {MyBehaviour.Function, 1}}
  """
  @spec spark_function_behaviour(module(), module(), {module(), non_neg_integer()}) ::
          {:spark_function_behaviour, module(), module(), {module(), non_neg_integer()}}
  def spark_function_behaviour(behaviour, builtin, {function_mod, arity})
      when is_atom(behaviour) and is_atom(builtin) and is_atom(function_mod) and is_integer(arity) and
             arity >= 0 do
    {:spark_function_behaviour, behaviour, builtin, {function_mod, arity}}
  end

  @doc """
  Spark type with builtin function.

  ## Examples

      iex> Spark.Builder.Type.spark_type(MyType, :builtins)
      {:spark_type, MyType, :builtins}
  """
  @spec spark_type(module(), atom()) :: {:spark_type, module(), atom()}
  def spark_type(module, builtin_function) when is_atom(module) and is_atom(builtin_function) do
    {:spark_type, module, builtin_function}
  end

  @doc """
  Spark type with builtin function and templates.

  ## Examples

      iex> Spark.Builder.Type.spark_type(MyType, :builtins, ["template1", "template2"])
      {:spark_type, MyType, :builtins, ["template1", "template2"]}
  """
  @spec spark_type(module(), atom(), list(String.t())) ::
          {:spark_type, module(), atom(), list(String.t())}
  def spark_type(module, builtin_function, templates)
      when is_atom(module) and is_atom(builtin_function) and is_list(templates) do
    {:spark_type, module, builtin_function, templates}
  end
end
