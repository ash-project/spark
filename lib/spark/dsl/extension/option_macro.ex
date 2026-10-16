# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Dsl.Extension.OptionMacro do
  @moduledoc false

  defmodule Config do
    @moduledoc false

    # Built once per option when Spark generates an options module, then escaped into
    # that option's macro. `path` is the entity path for deprecation warnings, or the
    # section path, which section options also write to. Only section options set
    # `extension`.
    @enforce_keys [:name, :type, :path, :deprecations, :modules, :no_depend_modules]
    defstruct @enforce_keys ++ [depend_on_only_behaviour_modules: [], extension: nil]

    @type t :: %__MODULE__{
            name: atom,
            type: term,
            path: [atom],
            deprecations: Keyword.t(),
            modules: [atom],
            no_depend_modules: [atom],
            depend_on_only_behaviour_modules: [atom],
            extension: module | nil
          }
  end

  @doc false
  def expand(%Config{name: field} = config, value, caller, setter) do
    Spark.Dsl.Extension.maybe_deprecated(field, config.deprecations, config.path, caller)

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
        config.depend_on_only_behaviour_modules,
        caller
      )

    Spark.CodeHelpers.lift_functions(value, field, caller)
  end
end
