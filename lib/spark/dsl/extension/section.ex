# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Dsl.Extension.Section do
  @moduledoc false

  @doc false
  def expand(config, body, caller) do
    %{
      opts_module: opts_module,
      section_path: section_path,
      extension: extension,
      entity_modules: entity_modules,
      section_modules: section_modules,
      imports: imports,
      after_define: after_define,
      module: module
    } = config

    section_anno = Spark.Dsl.Extension.macro_env_anno(caller, body[:do])

    patch_modules =
      Spark.Dsl.Extension.get_attribute(caller.module, :extensions)
      |> Spark.Dsl.Extension.get_entity_dsl_patches(section_path)
      |> Enum.reject(&(&1 in entity_modules))

    import_statements =
      Enum.concat([
        imports,
        entity_modules,
        patch_modules,
        section_modules,
        List.wrap(opts_module)
      ])
      |> Spark.Dsl.Extension.Imports.import_solving_conflicts(caller)

    all_the_code =
      import_statements ++
        [
          quote generated: true do
            unquote(body[:do])

            current_sections = Process.get({__MODULE__, :spark_sections}, [])

            unless {unquote(extension), unquote(section_path)} in current_sections do
              Process.put({__MODULE__, :spark_sections}, [
                {unquote(extension), unquote(section_path)} | current_sections
              ])
            end

            # Store section annotation
            current_config =
              Process.get(
                {__MODULE__, :spark, unquote(section_path)},
                Spark.Dsl.Extension.default_section_config()
              )

            Process.put(
              {__MODULE__, :spark, unquote(section_path)},
              %{current_config | section_anno: unquote(Macro.escape(section_anno))}
            )

            @validate_sections {unquote(section_path), unquote(module), unquote(extension)}
          end
        ]

    quote do
      with do
        unquote(all_the_code)

        case unquote(after_define) do
          nil ->
            :ok

          {m, f} ->
            Code.eval_quoted(apply(m, f, []), [], __ENV__)
        end
      end
    end
  end
end
