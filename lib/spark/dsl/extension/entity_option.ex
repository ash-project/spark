# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Dsl.Extension.EntityOption do
  @moduledoc false

  def expand(config, value, caller) do
    %{key: key} = config

    Spark.Dsl.Extension.OptionMacro.expand(
      key,
      value,
      config,
      config.nested_entity_path,
      caller,
      fn value, anno ->
        quote generated: true do
          Spark.Dsl.Extension.EntityOption.set_entity_option(
            __MODULE__,
            unquote(key),
            unquote(value),
            unquote(anno)
          )
        end
      end
    )
  end

  def set_entity_option(module, key, value, anno \\ nil) do
    nested_entity_path = Process.get(:recursive_builder_path)
    current_opts = Process.get({:builder_opts, nested_entity_path}, [])

    if Keyword.has_key?(current_opts, key) do
      # Get the annotation for this entity from the Process store
      entity_anno = Process.get({:builder_anno, nested_entity_path})

      raise Spark.Error.DslError,
        module: module,
        message: "Multiple values for key `#{inspect(key)}`",
        path: nested_entity_path,
        location: entity_anno
    end

    Process.put(
      {:builder_opts, nested_entity_path},
      Keyword.put(current_opts, key, value)
    )

    # Store property annotation if provided
    if anno do
      current_opts_anno = Process.get({:builder_opts_anno, nested_entity_path}, %{})

      Process.put(
        {:builder_opts_anno, nested_entity_path},
        Map.put(current_opts_anno, key, anno)
      )
    end
  end
end
