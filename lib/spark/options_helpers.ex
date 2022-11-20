defmodule Spark.OptionsHelpers do
  @moduledoc """
  Helpers for working with our superset of nimble options.


  ## Additional Types

  Spark provides the following additional option types for use when building DSLs or validating options.

  - `{:one_of, values}` - maps to `{:in, values}` for backwards compatibility
  - `{:tagged_tuple, tag, inner_type}` - maps to `{tag, type}`
  - `{:spark_behaviour, behaviour}` - expects a module that implements the given behaviour, and can be specified with options, i.e `mod` or `{mod, [opt: :val]}`
  - `{:spark_behaviour, behaviour, builtin_module}` - Same as the above, but also accepts a `builtin_module`. The builtin_module is used to provide additional options for the elixir_sense plugin.
  - `{:spark_function_behaviour, behaviour, {function_mod, arity}}` - expects a module that implements the given behaviour, and can be specified with options, i.e `mod` or `{mod, [opt: :val]}`, that also has a special module that supports being provided an anonymous function or MFA as the `:fun` option.
  - `{:spark_function_behaviour, behaviour, builtin_module, {function_mod, arity}}` - Same as the above, but also accepts a `builtin_module`. The builtin_module is used to provide additional options for the elixir_sense plugin.
  - `{:behaviour, behaviour}` - expects a module that implements a given behaviour.
  - `{:spark, dsl_module}` - expects a module that is a `Spark.Dsl`
  - `{:mfa_or_fun, arity}` - expects a function or MFA of a corresponding arity.
  - `{:spark_type, module, builtin_function}` - a behaviour that defines `builtin_function/0` that returns a list of atoms that map to built in variations of that thing.
  - `{:spark_type, module, builtin_function, templates}` - same as the above, but includes additional templates for elixir_sense autocomplete
  - `:literal` -> any literal value. Maps to `:any`, but is used for documentation.
  """

  @typedoc """
  Spark provides additional types on top of those provided by [NimbleOptions](https://hex.pm/packages/nimble_options).
  """
  @type type ::
          nimble_types
          | {:one_of, [type]}
          | {:tagged_tuple, tag :: type, inner_type :: type}
          | {:spark_behaviour, module}
          | {:spark_behaviour, module, module}
          | {:spark_function_behaviour, module, {module, integer}}
          | {:spark_function_behaviour, module, module, {module, integer}}
          | {:behaviour, module}
          | {:spark, module}
          | {:mfa_or_fun, non_neg_integer()}
          | {:spark_type, module, builtin_function :: atom}
          | {:spark_type, module, builtin_function :: atom, templates :: [String.t()]}
          | {:struct, module}
          | :literal

  @typedoc """
  The types as specified by the [NimbleOptions docs](https://hexdocs.pm/nimble_options/NimbleOptions.html#module-types).
  """
  @type nimble_types ::
          :any
          | :keyword_list
          | :non_empty_keyword_list
          | :map
          | {:map, key_type :: type, value_type :: type}
          | :atom
          | :string
          | :boolean
          | :integer
          | :non_neg_integer
          | :pos_integer
          | :float
          | :timeout
          | :pid
          | :reference
          | :mfa
          | :mod_arg
          | {:fun, arity :: non_neg_integer}
          | {:in, [type] | Range.t()}
          | {:custom, module, function :: atom, args :: [any]}
          | {:or, [type]}
          | {:list, type | {:keyword_list, type} | {:non_empty_keyword_list, type}}
          | {:tuple, [type | {:keyword_list, type} | {:non_empty_keyword_list, type}]}

  @typedoc """
  The schema type, as defined by the [NimbleOptions docs](https://hexdocs.pm/nimble_options/NimbleOptions.html#module-schema-options).
  """
  @type nimble_schema :: [
          {:type, type | :any}
          | {:required, boolean}
          | {:default, :any}
          | {:keys, Keyword.t({:type, type})}
          | {:deprecated, String.t()}
          | {:doc, String.t()}
          | {:subsection, String.t()}
          | {:type_doc, false | String.t()}
          | {:rename_to, atom}
        ]

  @typedoc """
  The actual schema type, as used in sections and entities.
  """
  @type schema :: Keyword.t(nimble_schema)

  @doc """
  Merges two schemas, and sets the `subsection` option on all options on the right
  side.
  """
  def merge_schemas(left, right, section \\ nil) do
    new_right =
      Enum.map(right, fn {key, value} ->
        {key, Keyword.put(value, :subsection, section)}
      end)

    Keyword.merge(left, new_right)
  end

  @doc """
  Sanitizes the option schema and validates with NimbleOptions.
  """
  def validate(opts, schema) do
    NimbleOptions.validate(opts, sanitize_schema(schema))
  end

  @doc """
  Sanitizes the option schema and validates with NimbleOptions.
  """
  def validate!(opts, schema) do
    NimbleOptions.validate!(opts, sanitize_schema(schema))
  end

  @doc """
  Creates markdown documentation for a given schema.
  """
  def docs(schema) do
    schema
    |> Enum.reject(fn {_key, opts} ->
      opts[:hide]
    end)
    |> sanitize_schema()
    |> Enum.map(fn {key, opts} ->
      if opts[:doc] do
        {key, Keyword.update!(opts, :doc, &String.replace(&1, "\n\n", "  \n"))}
      else
        {key, opts}
      end
    end)
    |> NimbleOptions.docs()
  end

  @non_nimble_options [:hide, :as, :snippet, :links]

  defp sanitize_schema(schema) do
    Enum.map(schema, fn {key, opts} ->
      new_opts = Keyword.update!(opts, :type, &sanitize_type(&1, key))
      {key, Keyword.drop(new_opts, @non_nimble_options)}
    end)
  end

  defp sanitize_type(type, key) when is_list(type) do
    Enum.map(type, &sanitize_type(&1, key))
  end

  defp sanitize_type(type, key) do
    case type do
      {:one_of, values} ->
        {:in, sanitize_type(values, key)}

      {:in, values} ->
        {:in, sanitize_type(values, key)}

      {:or, subtypes} ->
        {:or, sanitize_type(subtypes, key)}

      {:tagged_tuple, tag, type} ->
        {:custom, __MODULE__, :tagged_tuple, [key, type, tag]}

      {:struct, struct} ->
        {:custom, __MODULE__, :struct, [struct]}

      {:list, values} ->
        {:list, sanitize_type(values, key)}

      {:spark_behaviour, behaviour, _builtins} ->
        {:custom, __MODULE__, :spark_behaviour, [behaviour]}

      {:spark_behaviour, behaviour} ->
        {:custom, __MODULE__, :spark_behaviour, [behaviour]}

      {:spark_function_behaviour, behaviour, _builtins, {functional, arity}} ->
        {:custom, __MODULE__, :spark_function_behaviour, [behaviour, {functional, arity}]}

      {:spark_function_behaviour, behaviour, {functional, arity}} ->
        {:custom, __MODULE__, :spark_function_behaviour, [behaviour, {functional, arity}]}

      {:behaviour, _behaviour} ->
        :atom

      {:spark, _} ->
        :atom

      {:mfa_or_fun, arity} ->
        {:custom, __MODULE__, :mfa_or_fun, [arity]}

      {:spark_type, _, _} ->
        :any

      {:spark_type, _, _, _} ->
        :any

      :literal ->
        :any

      type ->
        type
    end
  end

  def tagged_tuple({tag, value}, key, type, tag) do
    case Spark.OptionsHelpers.validate(
           [{key, value}],
           [
             {key,
              [
                type: type
              ]}
           ]
         ) do
      {:ok, opts} ->
        {:ok, {tag, opts[key]}}

      {:error, %NimbleOptions.ValidationError{message: message}} ->
        {:error, message}
    end
  end

  def tagged_tuple(other, _key, _type, tag) do
    {:error,
     "Expected a tagged tuple in the form of {#{inspect(tag)}, value}, got: #{inspect(other)}"}
  end

  def spark_behaviour({module, opts}, _behaviour) when is_atom(module) do
    if Keyword.keyword?(opts) do
      # We can't check if it implements the behaviour here, unfortunately
      # As it may not be immediately available
      {:ok, {module, opts}}
    else
      {:error, "Expected opts to be a keyword, got: #{inspect(opts)}"}
    end
  end

  def spark_behaviour(module, behaviour) when is_atom(module) do
    spark_behaviour({module, []}, behaviour)
  end

  def spark_behaviour(other, _) do
    {:error, "expected a module and opts, got: #{inspect(other)}"}
  end

  def spark_function_behaviour({module, opts}, _behaviour, {_functional, _arity})
      when is_atom(module) do
    if Keyword.keyword?(opts) do
      # We can't check if it implements the behaviour here, unfortunately
      # As it may not be immediately available
      {:ok, {module, opts}}
    else
      {:error, "Expected opts to be a keyword, got: #{inspect(opts)}"}
    end
  end

  def spark_function_behaviour(module, behaviour, {functional, arity}) when is_atom(module) do
    spark_function_behaviour({module, []}, behaviour, {functional, arity})
  end

  def spark_function_behaviour(function, _behaviour, {functional, arity})
      when is_function(function, arity) do
    {:ok, {functional, [fun: function]}}
  end

  def spark_function_behaviour(function, _behaviour, {_functional, arity})
      when is_function(function) do
    actual_arity = :erlang.fun_info(function)[:arity]

    {:error,
     "Expected a module and opts, or a #{arity} argument function. Got a #{actual_arity} argument function."}
  end

  def spark_function_behaviour(other, _, {_, arity}) do
    {:error,
     "Expected a module and opts, or a #{arity} argument function, got: #{inspect(other)}"}
  end

  def map(value) when is_map(value), do: {:ok, value}
  def map(_), do: {:error, "must be a map"}

  def struct(value, struct) when is_struct(value, struct), do: {:ok, value}
  def struct(_, struct), do: {:error, "must be a struct instance of #{inspect(struct)}"}

  @deprecated "Use {:list, :atom} instead"
  def list_of_atoms(value) do
    if is_list(value) and Enum.all?(value, &is_atom/1) do
      {:ok, value}
    else
      {:error, "Expected a list of atoms"}
    end
  end

  def module_and_opts({module, opts}) when is_atom(module) do
    if Keyword.keyword?(opts) do
      {:ok, {module, opts}}
    else
      {:error, "Expected the second element to be a keyword list, got: #{inspect(opts)}"}
    end
  end

  def module_and_opts({other, _}) do
    {:error, "Expected the first element to be a module, got: #{inspect(other)}"}
  end

  def module_and_opts(module) do
    module_and_opts({module, []})
  end

  def mfa_or_fun(value, arity) when is_function(value, arity), do: {:ok, value}

  def mfa_or_fun({module, function, args}, _arity)
      when is_atom(module) and is_atom(function) and is_list(args),
      do: {:ok, {module, function, args}}

  def mfa_or_fun(value, _), do: {:ok, value}

  def make_required!(options, field) do
    Keyword.update!(options, field, &Keyword.put(&1, :required, true))
  end

  def make_optional!(options, field) do
    Keyword.update!(options, field, &Keyword.delete(&1, :required))
  end

  def set_type!(options, field, type) do
    Keyword.update!(options, field, &Keyword.put(&1, :type, type))
  end

  def set_default!(options, field, value) do
    Keyword.update!(options, field, fn config ->
      config
      |> Keyword.put(:default, value)
      |> Keyword.delete(:required)
    end)
  end

  def append_doc!(options, field, to_append) do
    Keyword.update!(options, field, fn opt_config ->
      Keyword.update(opt_config, :doc, to_append, fn existing ->
        existing <> " - " <> to_append
      end)
    end)
  end
end
