defmodule Spark.Dsl.Extension.EntityOption do
  @moduledoc false

  def value_and_function(value, field, type, caller, modules, no_depend_modules) do
    value =
      case type do
        :quoted ->
          Macro.escape(value)

        _ ->
          value
      end

    value =
      cond do
        field in modules ->
          Spark.Dsl.Extension.expand_alias(value, caller)

        field in no_depend_modules ->
          Spark.Dsl.Extension.expand_alias_no_require(value, caller)

        true ->
          value
      end

    Spark.CodeHelpers.lift_functions(value, field, caller)
  end

  def set_entity_option(module, key, value) do
    nested_entity_path = Process.get(:recursive_builder_path)
    current_opts = Process.get({:builder_opts, nested_entity_path}, [])

    if Keyword.has_key?(current_opts, key) do
      raise Spark.Error.DslError,
        module: module,
        message: "Multiple values for key `#{inspect(key)}`",
        path: nested_entity_path
    end

    Process.put(
      {:builder_opts, nested_entity_path},
      Keyword.put(current_opts, key, value)
    )
  end
end
