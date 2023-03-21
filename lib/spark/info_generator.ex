defmodule Spark.InfoGenerator do
  @moduledoc """
  Used to dynamically generate configuration functions for Spark extensions
  based on their DSL.

  ## Usage

  ```elixir
  defmodule MyConfig do
    use Spark.InfoGenerator, extension: MyDslExtension, sections: [:my_section]
  end
  ```
  """

  @type options :: [{:extension, module} | {:sections, [atom]}]

  @doc false
  @spec __using__(options) :: Macro.t()
  defmacro __using__(opts) do
    extension = Keyword.fetch!(opts, :extension) |> Macro.expand(__CALLER__)
    sections = Keyword.get(opts, :sections, [])

    quote do
      require Spark.InfoGenerator
      require unquote(extension)

      Spark.InfoGenerator.generate_config_functions(
        unquote(extension),
        unquote(sections)
      )

      Spark.InfoGenerator.generate_options_functions(
        unquote(extension),
        unquote(sections)
      )

      Spark.InfoGenerator.generate_entity_functions(
        unquote(extension),
        unquote(sections)
      )
    end
  end

  @doc """
  Given an extension and a list of DSL sections, generate an options function
  which returns a map of all configured options for a resource (including
  defaults).
  """
  @spec generate_options_functions(module, [atom]) :: Macro.t()
  defmacro generate_options_functions(extension, sections) do
    for {path, options} <- extension_sections_to_option_list(extension, sections) do
      function_name = :"#{Enum.join(path, "_")}_options"

      quote location: :keep do
        @doc """
        #{unquote(Enum.join(path, "."))} DSL options

        Returns a map containing the and any configured or default values.
        """
        @spec unquote(function_name)(dsl_or_extended :: module | map) :: %{required(atom) => any}
        def unquote(function_name)(dsl_or_extended) do
          import Spark.Dsl.Extension, only: [get_opt: 4]

          unquote(Macro.escape(options))
          |> Stream.map(fn option ->
            value =
              dsl_or_extended
              |> get_opt(option.path, option.name, Map.get(option, :default))

            {option.name, value}
          end)
          |> Stream.reject(&is_nil(elem(&1, 1)))
          |> Map.new()
        end
      end
    end
  end

  @doc """
  Given an extension and a list of DSL sections, generate an entities function
  which returns a list of entities.
  """
  @spec generate_entity_functions(module, [atom]) :: Macro.t()
  defmacro generate_entity_functions(extension, sections) do
    entity_paths =
      extension.sections()
      |> Stream.filter(&(&1.name in sections))
      |> Stream.flat_map(&explode_section([], &1))
      |> Stream.filter(fn {_, section} -> section.patchable? || Enum.any?(section.entities) end)
      |> Stream.map(&elem(&1, 0))

    for path <- entity_paths do
      function_name = path |> Enum.join("_") |> String.to_atom()

      quote location: :keep do
        @doc """
        #{unquote(Enum.join(path, "."))} DSL entities
        """
        @spec unquote(function_name)(dsl_or_extended :: module | map) :: [struct]
        def unquote(function_name)(dsl_or_extended) do
          import Spark.Dsl.Extension, only: [get_entities: 2]

          get_entities(dsl_or_extended, unquote(path))
        end
      end
    end
  end

  @doc """
  Given an extension and a list of DSL sections generate individual config
  functions for each option.
  """
  @spec generate_config_functions(module, [atom]) :: Macro.t()
  defmacro generate_config_functions(extension, sections) do
    for {_, options} <- extension_sections_to_option_list(extension, sections) do
      for option <- options do
        generate_config_function(option)
      end
    end
  end

  defp explode_section(path, %{sections: [], name: name} = section),
    do: [{path ++ [name], section}]

  defp explode_section(path, %{sections: sections, name: name} = section) do
    path = path ++ [name]

    head = [{path, section}]
    tail = Stream.flat_map(sections, &explode_section(path, &1))

    Stream.concat(head, tail)
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp extension_sections_to_option_list(extension, sections) do
    extension.sections()
    |> Stream.filter(&(&1.name in sections))
    |> Stream.flat_map(&explode_section([], &1))
    |> Stream.reject(fn {_, section} -> Enum.empty?(section.schema) end)
    |> Stream.map(fn {path, section} ->
      schema =
        section.schema
        |> Enum.map(fn {name, opts} ->
          opts
          |> Map.new()
          |> Map.take(~w[type doc default]a)
          |> Map.update!(:type, &spec_for_type/1)
          |> Map.put(:pred?, name |> to_string() |> String.ends_with?("?"))
          |> Map.put(:name, name)
          |> Map.put(:path, path)
          |> Map.put(
            :function_name,
            path
            |> Enum.concat([name])
            |> Enum.join("_")
            |> String.trim_trailing("?")
            |> String.to_atom()
          )
        end)

      {path, schema}
    end)
    |> Map.new()
  end

  # sobelow_skip ["DOS.BinToAtom"]
  defp generate_config_function(%{pred?: true} = option) do
    function_name = :"#{option.function_name}?"

    quote location: :keep do
      @doc unquote(option.doc)
      @spec unquote(function_name)(dsl_or_extended :: module | map) ::
              unquote(option.type)
      def unquote(function_name)(dsl_or_extended) do
        import Spark.Dsl.Extension, only: [get_opt: 4]

        get_opt(
          dsl_or_extended,
          unquote(option.path),
          unquote(option.name),
          unquote(option.default)
        )
      end
    end
  end

  # sobelow_skip ["DOS.BinToAtom"]
  defp generate_config_function(option) do
    quote location: :keep do
      @doc unquote(Map.get(option, :doc, false))
      @spec unquote(option.function_name)(dsl_or_extended :: module | map) ::
              {:ok, unquote(option.type)} | :error

      def unquote(option.function_name)(dsl_or_extended) do
        import Spark.Dsl.Extension, only: [get_opt: 4]

        case get_opt(
               dsl_or_extended,
               unquote(option.path),
               unquote(option.name),
               unquote(Map.get(option, :default, :error))
             ) do
          :error -> :error
          value -> {:ok, value}
        end
      end

      # sobelow_skip ["DOS.BinToAtom"]
      @doc unquote(Map.get(option, :doc, false))
      @spec unquote(:"#{option.function_name}!")(dsl_or_extended :: module | map) ::
              unquote(option.type) | no_return
      def unquote(:"#{option.function_name}!")(dsl_or_extended) do
        import Spark.Dsl.Extension, only: [get_opt: 4]

        case get_opt(
               dsl_or_extended,
               unquote(option.path),
               unquote(option.name),
               unquote(Map.get(option, :default, :error))
             ) do
          :error ->
            raise "No configuration for `#{unquote(option.name)}` present on `#{inspect(dsl_or_extended)}`."

          value ->
            value
        end
      end
    end
  end

  defp spec_for_type({:literal, value}) when is_atom(value) or is_integer(value) do
    value
  end

  defp spec_for_type({:literal, value}) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&spec_for_type({:literal, &1}))
    |> List.to_tuple()
  end

  defp spec_for_type({:literal, value}) when is_list(value) do
    Enum.map(value, &spec_for_type({:literal, &1}))
  end

  defp spec_for_type({:literal, _value}) do
    {:any, [], Elixir}
  end

  defp spec_for_type({:behaviour, _module}), do: {:module, [], Elixir}

  defp spec_for_type({:spark_function_behaviour, behaviour, {_, arity}}),
    do:
      spec_for_type(
        {:or,
         [
           {:behaviour, behaviour},
           {{:behaviour, behaviour}, {:keyword, [], Elixir}},
           {:fun, arity}
         ]}
      )

  defp spec_for_type({:fun, arity}) do
    args =
      0..(arity - 1)
      |> Enum.map(fn _ -> {:any, [], Elixir} end)

    [{:->, [], [args, {:any, [], Elixir}]}]
  end

  defp spec_for_type({:or, [type]}), do: spec_for_type(type)

  defp spec_for_type({:or, [next | remaining]}),
    do: {:|, [], [spec_for_type(next), spec_for_type({:or, remaining})]}

  defp spec_for_type({:in, %Range{first: first, last: last}})
       when is_integer(first) and is_integer(last),
       do: {:.., [], [first, last]}

  defp spec_for_type({:in, %Range{first: first, last: last}}),
    do:
      {{:., [], [{:__aliases__, [], [:Range]}, :t]}, [],
       [spec_for_type(first), spec_for_type(last)]}

  defp spec_for_type({:in, [type]}), do: spec_for_type(type)

  defp spec_for_type({:in, [next | remaining]}),
    do: {:|, [], [spec_for_type(next), spec_for_type({:in, remaining})]}

  defp spec_for_type({:list, subtype}), do: [spec_for_type(subtype)]

  defp spec_for_type({:custom, _, _, _}), do: spec_for_type(:any)

  defp spec_for_type({:tuple, subtypes}) do
    subtypes
    |> Enum.map(&spec_for_type/1)
    |> List.to_tuple()
  end

  defp spec_for_type(:string),
    do: {{:., [], [{:__aliases__, [alias: false], [:String]}, :t]}, [], []}

  defp spec_for_type(:literal) do
    {:any, [], Elixir}
  end

  defp spec_for_type(terminal)
       when terminal in ~w[any map atom string boolean integer non_neg_integer pos_integer float timeout pid reference mfa]a,
       do: {terminal, [], Elixir}

  defp spec_for_type(atom) when is_atom(atom), do: atom
  defp spec_for_type(number) when is_number(number), do: number
  defp spec_for_type(string) when is_binary(string), do: spec_for_type(:string)

  defp spec_for_type({mod, arg}) when is_atom(mod) and is_list(arg),
    do: {{:module, [], Elixir}, {:list, [], Elixir}}

  defp spec_for_type(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&spec_for_type/1) |> List.to_tuple()

  defp spec_for_type([]), do: []
  defp spec_for_type([type]), do: [spec_for_type(type)]
end
