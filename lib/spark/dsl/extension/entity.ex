# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Dsl.Extension.Entity do
  @moduledoc false

  @doc false
  def build!(entity, section_path, module, opts, nested_entities, anno, opts_anno) do
    case Spark.Dsl.Entity.build(entity, opts, nested_entities, anno, opts_anno) do
      {:ok, built} ->
        built

      {:error, error} ->
        additional_path =
          if opts[:name] do
            [entity.name, opts[:name]]
          else
            [entity.name]
          end

        message =
          cond do
            is_exception(error) ->
              Exception.message(error)

            is_binary(error) ->
              error

            true ->
              inspect(error)
          end

        raise Spark.Error.DslError,
          module: module,
          message: message,
          path: section_path ++ additional_path,
          location: anno
    end
  end

  @doc false
  # The generated macro passes `entity` as its own argument, not inside `config`, so
  # the compiler stores it as the same literal that `__build__/5` already holds.
  def expand(entity, config, arg_asts, opts, caller) do
    %{
      section_path: section_path,
      entity_args: entity_args,
      options_mod_name: options_mod_name,
      extension: extension,
      nested_entity_mods: nested_entity_mods,
      nested_entity_path: nested_entity_path,
      deprecations: deprecations,
      nested_key: nested_key,
      builder: builder,
      entity_keys: entity_keys,
      depend_on_only_behaviour_modules: depend_on_only_behaviour_modules
    } = config

    entity_schema = entity.schema
    entity_deprecations = entity.deprecations

    do_block = if Keyword.keyword?(opts), do: opts[:do]
    anno = Spark.Dsl.Extension.macro_env_anno(caller, do_block)

    Spark.Dsl.Extension.maybe_deprecated(
      entity.name,
      deprecations,
      section_path ++ nested_entity_path,
      caller
    )

    {args_without_opts, opts} =
      entity_args
      |> Enum.zip(arg_asts)
      |> Spark.Dsl.Extension.escape_quoted(entity_schema, caller)
      |> Spark.Dsl.Extension.shuffle_opts_to_end(
        entity.args,
        entity_schema,
        entity.entities,
        opts
      )

    if not Keyword.keyword?(opts) do
      raise ArgumentError,
            "Expected an options list in #{entity.name} got #{Macro.to_string(opts)}"
    end

    opts = Spark.Dsl.Extension.escape_quoted(opts, entity_schema, caller)

    {opts, opt_funs} =
      Enum.reduce(opts, {[], []}, fn {key, value}, {keyword, opt_funs} ->
        {value, function} = Spark.CodeHelpers.lift_functions(value, key, caller)
        keyword = [{key, value} | keyword]

        if function do
          {keyword, [function | opt_funs]}
        else
          {keyword, opt_funs}
        end
      end)

    {arg_values, funs} =
      args_without_opts
      |> Enum.reduce({[], []}, fn {key, arg_value}, {args, funs} ->
        Spark.Dsl.Extension.maybe_deprecated(
          key,
          entity_deprecations,
          nested_entity_path,
          caller
        )

        arg_value =
          expand_module_value(entity, depend_on_only_behaviour_modules, key, arg_value, caller)

        {arg_value, new_function} =
          Spark.CodeHelpers.lift_functions(arg_value, key, caller)

        if is_nil(arg_value) &&
             Enum.any?(
               entity.args,
               &(is_tuple(&1) && elem(&1, 0) == :optional && elem(&1, 1) == key)
             ) do
          {args, funs}
        else
          {[{key, arg_value} | args], [new_function | funs]}
        end
      end)

    other_extension_modules =
      Spark.Dsl.Extension.get_attribute(caller.module, :extensions)
      |> Enum.reject(&(&1 == extension))
      |> Enum.flat_map(fn extension ->
        extension.dsl_patches()
        |> Enum.filter(fn
          %Spark.Dsl.Patch.AddEntity{section_path: ^section_path} ->
            true

          _ ->
            false
        end)
        |> Enum.map(& &1.entity)
        |> Enum.concat(
          Spark.Dsl.Extension.get_recursive_entities_for_path(
            extension.sections(),
            section_path
          )
        )
        |> Enum.uniq_by(& &1.name)
        |> Enum.map(&{extension, &1})
      end)
      |> Enum.map(fn {extension, entity} ->
        Spark.Dsl.Extension.entity_mod_name(
          extension.module_prefix(),
          [],
          section_path,
          entity
        )
      end)

    opts =
      Enum.map(opts, fn {key, value} ->
        Spark.Dsl.Extension.maybe_deprecated(
          key,
          entity_deprecations,
          nested_entity_path,
          caller
        )

        {key, expand_module_value(entity, depend_on_only_behaviour_modules, key, value, caller)}
      end)

    import_statements =
      Enum.concat([
        other_extension_modules,
        entity.imports,
        List.wrap(options_mod_name),
        nested_entity_mods
      ])
      |> Spark.Dsl.Extension.Imports.import_solving_conflicts(caller)

    code =
      import_statements ++
        funs ++
        opt_funs ++
        [
          quote generated: true do
            handle_data =
              Spark.Dsl.Extension.Entity.setup(
                __MODULE__,
                unquote(entity.recursive_as),
                unquote(nested_key),
                unquote(Keyword.delete(opts, :do)),
                unquote(arg_values),
                unquote(Macro.escape(anno))
              )

            unquote(opts[:do])

            Spark.Dsl.Extension.Entity.handle(
              __MODULE__,
              unquote(section_path),
              unquote(entity_keys),
              unquote(builder),
              unquote(extension),
              handle_data
            )
          end
        ]

    quote generated: true do
      with do
        unquote(code)
      end
    end
  end

  defp expand_module_value(entity, depend_on_only_behaviour_modules, key, value, caller) do
    Spark.Dsl.Extension.expand_module_option(
      key,
      value,
      entity.modules,
      entity.no_depend_modules,
      depend_on_only_behaviour_modules,
      caller
    )
  end

  def setup(module, recursive_as, nested_key, opts, arg_values, anno) do
    parent_recursive_as = Process.get(:parent_recursive_as)
    original_nested_entity_path = Process.get(:recursive_builder_path)

    nested_entity_path =
      if is_nil(original_nested_entity_path) do
        Process.put(:recursive_builder_path, [])
        []
      else
        unless recursive_as || nested_key || parent_recursive_as do
          raise "Somehow got a nested entity without a `recursive_as` or `nested_key`"
        end

        path =
          (original_nested_entity_path || []) ++
            [recursive_as || nested_key || parent_recursive_as]

        Process.put(
          :recursive_builder_path,
          path
        )

        path
      end

    if recursive_as do
      Process.put(:parent_recursive_as, recursive_as)
    end

    current_sections = Process.get({module, :spark_sections}, [])

    keyword_opts =
      Keyword.merge(
        opts,
        arg_values,
        fn key, _, _ ->
          raise Spark.Error.DslError,
            module: module,
            message: "Multiple values for key `#{inspect(key)}`",
            path: nested_entity_path,
            location: anno
        end
      )

    Process.put(
      {:builder_opts, nested_entity_path},
      keyword_opts
    )

    # Store annotation for entity options error reporting
    Process.put({:builder_anno, nested_entity_path}, anno)

    {original_nested_entity_path, parent_recursive_as, nested_entity_path, current_sections, anno}
  end

  def handle(
        module,
        section_path,
        nested_entity_keys,
        entity_builder,
        extension,
        {original_nested_entity_path, parent_recursive_as, nested_entity_path, current_sections,
         anno}
      ) do
    Process.put(:recursive_builder_path, original_nested_entity_path)
    Process.put(:parent_recursive_as, parent_recursive_as)

    current_config =
      Process.get(
        {module, :spark, section_path ++ nested_entity_path},
        Spark.Dsl.Extension.default_section_config()
      )

    opts = Process.delete({:builder_opts, nested_entity_path})
    opts_anno = Process.delete({:builder_opts_anno, nested_entity_path})
    Process.delete({:builder_anno, nested_entity_path})

    nested_entities =
      nested_entity_keys
      |> Enum.reduce(%{}, fn key, acc ->
        nested_path = section_path ++ nested_entity_path ++ [key]

        entities =
          {module, :spark, nested_path}
          |> Process.get(%{entities: []})
          |> Map.get(:entities, [])

        Process.delete({module, :spark, nested_path})

        Map.update(acc, key, entities, fn current_nested_entities ->
          (current_nested_entities || []) ++ entities
        end)
      end)

    Spark.Dsl.Entity.put_module(module)
    built = entity_builder.__build__(module, opts, nested_entities, anno, opts_anno)

    new_config = %{current_config | entities: current_config.entities ++ [built]}

    unless {extension, section_path} in current_sections do
      Process.put({module, :spark_sections}, [
        {extension, section_path} | current_sections
      ])
    end

    Process.put(
      {module, :spark, section_path ++ nested_entity_path},
      new_config
    )
  end
end
