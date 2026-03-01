# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Dsl.Verifiers.VerifySectionSingletonEntities do
  @moduledoc """
  Verifies that entities specified in a section's `singleton_entity_keys`
  appear at most once within that section.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    dsl_state
    |> Verifier.get_persisted(:extensions)
    |> Enum.each(fn extension ->
      Enum.each(extension.sections(), fn section ->
        verify_section(module, section, dsl_state)
      end)
    end)

    :ok
  end

  defp verify_section(module, section, dsl_state, path \\ []) do
    section_path = path ++ [section.name]

    case section.singleton_entity_keys do
      [] ->
        :ok

      singleton_keys ->
        entities = Verifier.get_entities(dsl_state, section_path)

        Enum.each(singleton_keys, fn key ->
          entity_def = Enum.find(section.entities, &(&1.name == key))

          if entity_def do
            matching =
              Enum.filter(entities, &(&1.__struct__ == entity_def.target))

            if length(matching) > 1 do
              location =
                case matching do
                  [_, second | _] -> Spark.Dsl.Entity.anno(second)
                  _ -> nil
                end

              raise Spark.Error.DslError,
                module: module,
                path: section_path,
                message:
                  "Expected at most one #{key} in #{inspect(section_path)}, got #{length(matching)}",
                location: location
            end
          end
        end)
    end

    Enum.each(section.sections, fn nested_section ->
      verify_section(module, nested_section, dsl_state, section_path)
    end)
  end
end
