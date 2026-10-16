# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Dsl.Extension.OptionMacro do
  @moduledoc false

  @doc false
  def expand(field, value, config, deprecation_path, caller, setter) do
    Spark.Dsl.Extension.maybe_deprecated(field, config.deprecations, deprecation_path, caller)

    {value, function} = value_and_function(value, field, config, caller)
    anno = Macro.escape(Spark.Dsl.Extension.macro_env_anno(caller, nil))

    quote generated: true do
      unquote(function)
      unquote(setter.(value, anno))
    end
  end

  defp value_and_function(value, field, config, caller) do
    value =
      case config.type do
        :quoted ->
          Macro.escape(value)

        _ ->
          value
      end

    value =
      Spark.Dsl.Extension.expand_module_option(
        field,
        value,
        config.modules,
        config.no_depend_modules,
        Map.get(config, :depend_on_only_behaviour_modules, []),
        caller
      )

    Spark.CodeHelpers.lift_functions(value, field, caller)
  end
end
