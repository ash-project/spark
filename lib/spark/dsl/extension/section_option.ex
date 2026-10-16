# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Dsl.Extension.SectionOption do
  @moduledoc false

  def expand(config, value, caller) do
    %{section_path: section_path, field: field, extension: extension} = config

    opt_anno = Spark.Dsl.Extension.macro_env_anno(caller, nil)

    Spark.Dsl.Extension.maybe_deprecated(field, config.deprecations, section_path, caller)

    {value, function} =
      value_and_function(
        value,
        field,
        config.type,
        caller,
        config.modules,
        config.no_depend_modules
      )

    quote generated: true do
      unquote(function)

      Spark.Dsl.Extension.SectionOption.set_section_option(
        __MODULE__,
        unquote(extension),
        unquote(section_path),
        unquote(field),
        unquote(value),
        unquote(Macro.escape(opt_anno))
      )
    end
  end

  def set_and_validate_options(dsl_config, section_path, module, schema) do
    dsl_config
    |> Map.put_new(section_path, Spark.Dsl.Extension.default_section_config())
    |> Map.update!(section_path, fn config ->
      validated_opts =
        case Spark.Options.validate(Keyword.new(config[:opts] || []), schema) do
          {:ok, opts} ->
            opts

          {:error, error} ->
            raise Spark.Error.DslError,
              module: module,
              message: error,
              path: section_path,
              location: config[:section_anno]
        end

      %{config | opts: validated_opts}
    end)
  end

  def value_and_function(value, field, type, caller, section_modules, section_no_depend_modules) do
    value =
      case type do
        :quoted ->
          Macro.escape(value)

        _ ->
          value
      end

    value =
      cond do
        field in section_modules ->
          Spark.Dsl.Extension.expand_alias(value, caller)

        field in section_no_depend_modules ->
          Spark.Dsl.Extension.expand_alias_no_require(value, caller)

        true ->
          value
      end

    Spark.CodeHelpers.lift_functions(value, field, caller)
  end

  def set_section_option(module, extension, section_path, field, value, anno \\ nil) do
    current_sections = Process.get({module, :spark_sections}, [])

    unless {extension, section_path} in current_sections do
      Process.put({module, :spark_sections}, [
        {extension, section_path} | current_sections
      ])
    end

    current_config =
      Process.get(
        {module, :spark, section_path},
        Spark.Dsl.Extension.default_section_config()
      )

    opts_anno =
      if anno do
        Keyword.put(current_config[:opts_anno] || [], field, anno)
      else
        current_config[:opts_anno] || []
      end

    Process.put(
      {module, :spark, section_path},
      %{
        current_config
        | opts: Keyword.put(current_config.opts, field, value),
          opts_anno: opts_anno
      }
    )
  end
end
