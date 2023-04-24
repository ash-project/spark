defmodule Spark.ElixirSense.Plugin do
  @moduledoc false

  Module.register_attribute(__MODULE__, :is_elixir_sense_plugin, persist: true)
  @is_elixir_sense_plugin true

  case Code.ensure_compiled(ElixirSense.Plugin) do
    {:module, _} ->
      @behaviour ElixirSense.Plugin
      @behaviour ElixirSense.Providers.Suggestion.GenericReducer

    _ ->
      :ok
  end

  def reduce(hint, env, buffer_metadata, cursor_context, acc) do
    apply(ElixirSense.Providers.Suggestion.GenericReducer, :reduce, [
      __MODULE__,
      hint,
      env,
      buffer_metadata,
      cursor_context,
      acc
    ])
  end

  alias ElixirSense.Providers.Suggestion.Matcher
  alias Spark.ElixirSense.Entity
  alias Spark.ElixirSense.Types

  def suggestions(hint, {_, function_call, arg_index, info}, _chain, opts) do
    opts = add_module_store(opts)
    option = info.option || get_option(opts.cursor_context.text_before)

    if option do
      get_suggestions(hint, opts, [function_call], {:value, option})
    else
      get_suggestions(hint, opts, [function_call], {:arg, arg_index})
    end
  end

  def suggestions(hint, opts) do
    opts = add_module_store(opts)
    option = get_section_option(opts.cursor_context.text_before)

    if option do
      get_suggestions(hint, opts, [], {:value, option})
    else
      get_suggestions(hint, opts)
    end
  end

  # For some reason, the module store does not change when modules are defined
  # so we are building our own fresh copy here. This is definitely a performance
  # hit
  defp add_module_store(opts) do
    Map.put(opts, :module_store, apply(ElixirSense.Core.ModuleStore, :build, [all_loaded()]))
  end

  defp all_loaded do
    :code.all_loaded()
    |> Enum.filter(fn
      {mod, _} when is_atom(mod) -> true
      _ -> false
    end)
    |> Enum.map(&elem(&1, 0))
  end

  def get_suggestions(hint, opts, opt_path \\ [], type \\ nil) do
    is_spark_entity? = is_dsl?(opts.env) || is_fragment?(opts.env)

    with true <- is_spark_entity?,
         dsl_mod when not is_nil(dsl_mod) <- get_dsl_mod(opts) do
      extension_kinds =
        List.flatten(dsl_mod.module_info[:attributes][:spark_extension_kinds] || [])

      extensions = default_extensions(dsl_mod) ++ parse_extensions(opts, extension_kinds)

      scopes_to_lines =
        Enum.reduce(opts.buffer_metadata.lines_to_env, %{}, fn {line, env}, acc ->
          line = line - 1

          Map.update(acc, env.scope_id, line, fn existing ->
            if existing < line do
              existing
            else
              line
            end
          end)
        end)

      scope_path = get_scope_path(opts, scopes_to_lines, nil, opt_path)

      case get_constructors(extensions, scope_path, hint, type) do
        [] ->
          :ignore

        constructors ->
          suggestions =
            case find_option(constructors, type) do
              {key, config} ->
                option_values(key, config, hint, opts)

              _ ->
                # Check for an edge case where we are editing the first argument of a constructor
                with {:value, option} <- type,
                     entity when not is_nil(entity) <-
                       find_building_entity(constructors, option),
                     [arg | _] <- Spark.Dsl.Entity.arg_names(entity),
                     config when not is_nil(config) <- entity.schema[arg] do
                  option_values(arg, config, hint, opts)
                else
                  _ ->
                    hint =
                      case type do
                        {:value, val} when not is_nil(val) ->
                          to_string(val)

                        _ ->
                          nil
                      end

                    Enum.map(constructors, fn
                      {key, config} ->
                        option_suggestions(key, config, type)

                      %{__struct__: Spark.Dsl.Entity} = entity ->
                        entity_suggestions(entity)

                      %{__struct__: Spark.Dsl.Section} = section ->
                        section_suggestions(section)
                    end)
                    |> filter_matches(hint)
                end
            end

          {:override, List.flatten(suggestions)}
      end
    else
      _ ->
        :ignore
    end
  end

  defp filter_matches(hints, match) do
    if match do
      Enum.filter(hints, fn %{label: label} ->
        apply(Matcher, :match?, [label, match])
      end)
    else
      hints
    end
  end

  defp is_dsl?(env) do
    Enum.any?(env.attributes, &(&1.name == :spark_is)) ||
      Enum.any?(env.requires, fn module ->
        try do
          module.module_info(:attributes)
          |> Enum.any?(fn
            {:spark_dsl, [true]} ->
              true

            _ ->
              false
          end)
        rescue
          _ -> false
        end
      end)
  end

  defp is_fragment?(env) do
    Enum.any?(env.attributes, &(&1.name == :spark_fragment_of)) ||
      Spark.Dsl.Fragment in env.requires
  end

  defp get_dsl_mod(opts) do
    if Spark.Dsl.Fragment in opts.env.requires do
      parse_fragment(opts)
    else
      Enum.find(opts.env.requires, &spark_extension?/1)
    end
  end

  defp parse_fragment(opts) do
    case Regex.named_captures(
           ~r/of:\s+?(?<of>|([^\s]*))?[\,\s$]/,
           opts.cursor_context.text_before
         ) do
      %{"of" => dsl} when dsl != "" ->
        module = Module.concat([dsl])

        if Code.ensure_loaded?(module) do
          module
        end

      _ ->
        nil
    end
  rescue
    _ -> false
  end

  defp find_building_entity(constructors, option) do
    Enum.find(constructors, fn
      %{__struct__: Spark.Dsl.Entity, name: ^option} ->
        true

      _ ->
        false
    end)
  end

  defp find_option(constructors, {:value, option}) do
    Enum.find_value(constructors, fn
      {^option, _} = opt ->
        opt

      %{__struct__: Spark.Dsl.Entity, name: ^option, args: [arg | _], schema: schema} ->
        {arg, schema[arg]}

      _ ->
        false
    end)
  end

  defp find_option(constructors, {:arg, arg_index}) do
    Enum.find(constructors, fn
      {_option, config} ->
        config[:arg_index] == arg_index

      _ ->
        false
    end)
  end

  defp find_option(_, _), do: nil

  defp section_suggestions(section) do
    snippet = Map.get(section, :snippet)

    snippet =
      if snippet && snippet != "" do
        snippet
      else
        "$0"
      end

    %{
      type: :generic,
      kind: :function,
      label: to_string(section.name),
      snippet: "#{section.name} do\n  #{snippet}\nend",
      detail: "Dsl Section",
      documentation: Map.get(section, :docs) || ""
    }
  end

  defp entity_suggestions(entity) do
    %{
      type: :generic,
      kind: :function,
      label: to_string(entity.name),
      snippet: "#{entity.name} #{args(entity)}",
      detail: "Dsl Entity",
      documentation: Map.get(entity, :docs) || ""
    }
  end

  defp option_suggestions(key, config, type) do
    snippet =
      if config[:snippet] && config[:snippet] != "" do
        config[:snippet]
      else
        default_snippet(config)
      end

    snippet =
      case type do
        :option ->
          "#{key}: #{snippet}"

        {:arg, _} ->
          "#{key}: #{snippet}"

        _ ->
          "#{key} #{snippet}"
      end

    config = Spark.OptionsHelpers.update_key_docs(config)

    %{
      type: :generic,
      kind: :function,
      label: to_string(key),
      snippet: snippet,
      detail: "Option",
      documentation: config[:doc]
    }
  end

  defp get_option(text) when is_binary(text) do
    case Regex.named_captures(~r/\s(?<option>[^\s]*):[[:blank:]]*$/, text) do
      %{"option" => option} when option != "" ->
        try do
          String.to_existing_atom(option)
        rescue
          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp get_option(_), do: nil

  defp get_section_option(text) when is_binary(text) do
    case Regex.named_captures(~r/\n[[:blank:]]+(?<option>[^\s]*)[[:blank:]]*$/, text) do
      %{"option" => option} when option != "" ->
        try do
          String.to_existing_atom(option)
        rescue
          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp get_section_option(_), do: nil

  defp option_values(key, config, hint, opts) do
    case config[:type] do
      :boolean ->
        enum_suggestion([true, false], hint, "boolean")

      {:one_of, values} ->
        enum_suggestion(values, hint, to_string(key))

      {:in, values} ->
        enum_suggestion(values, hint, to_string(key))

      {:spark_type, module, func} ->
        Types.find_builtin_types(module, func, hint, opts.cursor_context) ++
          Types.find_custom_types(module, func, hint, opts.module_store)

      {:spark_type, module, func, templates} ->
        Types.find_builtin_types(module, func, hint, opts.cursor_context, templates) ++
          Types.find_custom_types(module, func, hint, opts.module_store)

      {:spark, type} ->
        Entity.find_entities(type, hint)

      {:spark_behaviour, behaviour, builtins} ->
        Entity.find_spark_behaviour_impls(behaviour, builtins, hint, opts.module_store)

      {:spark_function_behaviour, behaviour, builtins, _} ->
        Entity.find_spark_behaviour_impls(behaviour, builtins, hint, opts.module_store)

      {:behaviour, behaviour} ->
        Entity.find_spark_behaviour_impls(behaviour, nil, hint, opts.module_store)

      {:spark_behaviour, behaviour} ->
        Entity.find_spark_behaviour_impls(behaviour, nil, hint, opts.module_store)

      {:spark_function_behaviour, behaviour, _} ->
        Entity.find_spark_behaviour_impls(behaviour, nil, hint, opts.module_store)

      {:or, subtypes} ->
        Enum.flat_map(subtypes, fn subtype ->
          option_values(key, Keyword.put(config, :type, subtype), hint, opts)
        end)

      _ ->
        []
    end
  end

  defp enum_suggestion(values, hint, label) do
    Enum.flat_map(values, fn v ->
      inspected = inspect(v)

      if apply(Matcher, :match?, [inspected, hint]) do
        [
          %{
            type: :generic,
            kind: :type_parameter,
            label: label,
            insert_text: inspect(v),
            snippet: inspect(v),
            documentation: inspect(v),
            priority: 0
          }
        ]
      else
        []
      end
    end)
  end

  defp default_snippet(config) do
    cond do
      config[:type] == :boolean && config[:default] in [true, false] ->
        "#{to_string(!config[:default])}"

      config[:type] == :string ->
        "\"$0\""

      match?(
        {list_type, {in_type, _list}}
        when list_type in [:wrap_list, :list] and in_type == [:in, :one_of],
        config[:type]
      ) ->
        {_, inner_type} = config[:type]
        "[#{default_snippet(type: inner_type)}]"

      match?({list_type, _} when list_type in [:wrap_list, :list], config[:type]) ->
        {_, inner_type} = config[:type]
        "[#{default_snippet(type: inner_type)}]"

      match?({in_type, _} when in_type in [:in, :one_of], config[:type]) ->
        {_, list} = config[:type]

        if is_nil(config[:default]) do
          {_, list} = config[:type]
          inspect(Enum.at(list, 0))
        else
          list |> Enum.reject(&(&1 == config[:default])) |> Enum.at(0) |> inspect()
        end

      match?({:tagged_tuple, _, _}, config[:type]) ->
        {:tagged_tuple, tag, inner_type} = config[:type]
        "{:#{tag}, #{default_snippet(inner_type)}}"

      config[:type] == :atom ->
        ":$0"

      match?({:mfa_or_fun, _}, config[:type]) ->
        {:mfa_or_fun, arity} = config[:type]
        default_snippet(type: {:or, [{:fun, arity}, :mfa]})

      match?({:literal, _}, config[:type]) ->
        {:literal, value} = config[:type]
        inspect(value)

      match?({:fun, 0}, config[:type]) ->
        """
        fn ->
          ${0:body}
        end
        """

      match?({:fun, _}, config[:type]) ->
        {:fun, arity} = config[:type]
        args = Enum.map_join(0..(arity - 1), ", ", &"arg#{&1 + 1}")

        """
        fn #{args} ->
          ${#{arity}:body}
        end
        """

      match?(:map, config[:type]) || match?({:map, _, _}, config[:type]) ->
        "%{${1:key} => ${2:value}}"

      match?(:keyword_list, config[:type]) ->
        "[${1:key} => ${2:value}]"

      config[:type] == :mfa ->
        "{${1:module}, :${2:function}, [${3:args}]}"

      config[:type] == :keyword_list ->
        "[$0]"

      true ->
        "$0"
    end
  end

  defp args(entity) do
    case Spark.Dsl.Entity.arg_names(entity) do
      [] ->
        ""

      args ->
        args
        |> Enum.with_index()
        |> Enum.map(fn {arg, index} ->
          "${#{index + 1}:#{arg}}"
        end)
        |> Enum.intersperse(", ")
        |> Enum.join()
    end
  end

  defp get_constructors(extensions, [], hint, type) do
    Enum.flat_map(
      extensions,
      fn extension ->
        try do
          top_level_constructors =
            extension.sections()
            |> Enum.filter(& &1.top_level?)
            |> Enum.flat_map(fn section ->
              do_find_constructors(section, [], hint, type)
            end)

          extension.sections()
          |> apply_dsl_patches(extensions)
          |> Enum.filter(fn section ->
            !section.top_level? &&
              apply(Matcher, :match?, [to_string(section.name), hint])
          end)
          |> Enum.concat(top_level_constructors)
        rescue
          _ ->
            []
        end
      end
    )
  end

  defp get_constructors(extensions, [first | rest], hint, type) do
    extensions
    |> Enum.flat_map(& &1.sections())
    |> Enum.filter(& &1.top_level?)
    |> Enum.find(fn section ->
      Enum.any?(section.sections, &(&1.name == first)) ||
        Enum.any?(section.entities, &(&1.name == first))
    end)
    |> case do
      nil ->
        Enum.flat_map(
          extensions,
          fn extension ->
            try do
              Enum.flat_map(apply_dsl_patches(extension.sections(), extensions), fn section ->
                if section.name == first do
                  do_find_constructors(section, rest, hint, type)
                else
                  []
                end
              end)
            rescue
              _ ->
                []
            end
          end
        )

      top_level_section ->
        do_find_constructors(top_level_section, [first | rest], hint, type)
    end
  end

  defp apply_dsl_patches(sections_or_entities, extensions, path \\ [])

  defp apply_dsl_patches(sections_or_entities, extensions, path)
       when is_list(sections_or_entities) do
    Enum.map(sections_or_entities, &apply_dsl_patches(&1, extensions, path))
  end

  defp apply_dsl_patches(%Spark.Dsl.Entity{} = entity, _, _), do: entity

  defp apply_dsl_patches(%Spark.Dsl.Section{} = section, extensions, path) do
    section_path_matcher = path ++ [section.name]

    new_entities =
      Enum.flat_map(extensions, fn extension ->
        extension.dsl_patches()
        |> Enum.flat_map(fn
          %Spark.Dsl.Patch.AddEntity{section_path: ^section_path_matcher, entity: entity} ->
            [entity]

          _ ->
            []
        end)
      end)

    %{
      section
      | sections:
          Enum.map(section.sections, &apply_dsl_patches(&1, extensions, path ++ [section.name])),
        entities: section.entities ++ new_entities
    }
  end

  defp do_find_constructors(entity_or_section, path, hint, type, recursives \\ [])

  defp do_find_constructors(
         %{__struct__: Spark.Dsl.Entity} = entity,
         [],
         hint,
         type,
         recursives
       ) do
    case type do
      {:value, _value} ->
        entity.schema ++
          Enum.flat_map(entity.entities || [], &elem(&1, 1)) ++
          Enum.uniq(recursives ++ List.wrap(recursive_for(entity)))

      {:arg, arg_index} ->
        if arg_index >= Enum.count(entity.args || []) do
          find_opt_hints(entity, hint) ++
            find_entity_hints(entity, hint, recursives)
        else
          Enum.map(entity.schema, fn {key, value} ->
            arg_index = Enum.find_index(Spark.Dsl.Entity.arg_names(entity), &(&1 == key))

            if arg_index do
              {key, Keyword.put(value, :arg_index, arg_index)}
            else
              {key, value}
            end
          end) ++
            Enum.uniq(
              recursives ++
                List.wrap(recursive_for(entity))
            )
        end

      _ ->
        find_opt_hints(entity, hint) ++
          find_entity_hints(entity, hint, recursives)
    end
  end

  defp do_find_constructors(section, [], hint, _type, recursives) do
    find_opt_hints(section, hint) ++
      find_entity_hints(section, hint, []) ++
      Enum.filter(section.sections, fn section ->
        apply(Matcher, :match?, [to_string(section.name), hint])
      end) ++ recursives
  end

  defp do_find_constructors(
         %{__struct__: Spark.Dsl.Entity} = entity,
         [next | rest],
         hint,
         type,
         recursives
       ) do
    entity.entities
    |> Kernel.||([])
    |> Enum.flat_map(&elem(&1, 1))
    |> Enum.concat(recursives)
    |> Enum.concat(List.wrap(recursive_for(entity)))
    |> Enum.filter(&(&1.name == next))
    |> Enum.flat_map(
      &do_find_constructors(
        &1,
        rest,
        hint,
        type,
        Enum.uniq(recursives ++ List.wrap(recursive_for(entity)))
      )
    )
    |> Enum.uniq()
  end

  defp do_find_constructors(section, [first | rest], hint, type, recursives) do
    Enum.flat_map(section.entities, fn entity ->
      if entity.name == first do
        do_find_constructors(entity, rest, hint, type)
      else
        []
      end
    end) ++
      Enum.flat_map(section.sections, fn section ->
        if section.name == first do
          do_find_constructors(section, rest, hint, type)
        else
          []
        end
      end) ++ recursives
  end

  defp recursive_for(entity) do
    if entity.recursive_as do
      entity
    end
  end

  defp find_opt_hints(%{__struct__: Spark.Dsl.Entity} = entity, hint) do
    Enum.flat_map(entity.schema, fn {key, value} ->
      if apply(Matcher, :match?, [to_string(key), hint]) do
        arg_index = Enum.find_index(Spark.Dsl.Entity.arg_names(entity), &(&1 == key))

        if arg_index do
          [{key, Keyword.put(value, :arg_index, arg_index)}]
        else
          [{key, value}]
        end
      else
        []
      end
    end)
  end

  defp find_opt_hints(section, hint) do
    Enum.filter(section.schema, fn {key, _value} ->
      apply(Matcher, :match?, [to_string(key), hint])
    end)
  end

  defp find_entity_hints(%{__struct__: Spark.Dsl.Entity} = entity, hint, recursives) do
    entity.entities
    |> Keyword.values()
    |> Enum.concat(recursives)
    |> Enum.concat(List.wrap(recursive_for(entity)))
    |> List.flatten()
    |> Enum.filter(fn entity ->
      apply(Matcher, :match?, [to_string(entity.name), hint])
    end)
  end

  defp find_entity_hints(section, hint, _recursives) do
    Enum.filter(section.entities, fn entity ->
      apply(Matcher, :match?, [to_string(entity.name), hint])
    end)
  end

  defp get_scope_path(opts, scopes_to_lines, env, path) do
    env = env || opts.env

    with earliest_line when not is_nil(earliest_line) <-
           scopes_to_lines[env.scope_id],
         [%{func: func}] when func != :defmodule <-
           opts.buffer_metadata.calls[earliest_line],
         next_env when not is_nil(next_env) <-
           opts.buffer_metadata.lines_to_env[earliest_line] do
      get_scope_path(opts, scopes_to_lines, next_env, [func | path])
    else
      _ ->
        path
    end
  end

  defp spark_extension?(module) do
    true in List.wrap(module.module_info()[:attributes][:spark_dsl])
  rescue
    _ -> false
  end

  defp default_extensions(dsl_mod) do
    dsl_mod.module_info[:attributes][:spark_default_extensions]
    |> List.wrap()
    |> List.flatten()
  end

  defp parse_extensions(opts, extension_kinds) do
    Enum.flat_map([:extensions | extension_kinds], fn extension_kind ->
      case Regex.named_captures(
             ~r/#{extension_kind}:\s+?(?<extensions>(\[[^\]]*\])|([^\s]*))?[\,\s$]/,
             opts.cursor_context.text_before
           ) do
        %{"extensions" => extensions} when extensions != "" ->
          extensions
          |> String.replace("[", "")
          |> String.replace("]", "")
          |> String.split(",")
          |> Enum.map(&String.trim/1)

        _ ->
          []
      end
    end)
    |> Enum.uniq()
    |> Enum.map(&Module.concat([&1]))
    |> Enum.filter(fn module ->
      try do
        Code.ensure_loaded?(module)
      rescue
        _ ->
          false
      end
    end)
  end
end
