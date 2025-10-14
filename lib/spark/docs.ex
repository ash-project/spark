# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Docs do
  @moduledoc """
  Tools for generating docs & search data for extras.
  """

  @doc """
  Generates searchable documentation suitable for ex_doc
  """
  def search_data_for(dsl) do
    dsl.sections()
    |> Enum.flat_map(fn section ->
      section_search_data(section)
    end)
    |> Enum.concat(
      Enum.flat_map(dsl.dsl_patches(), fn %Spark.Dsl.Patch.AddEntity{
                                            section_path: section_path,
                                            entity: entity
                                          } ->
        entity_search_data(entity, section_path)
      end)
    )
  end

  defp section_search_data(section, path \\ []) do
    schema_path =
      if section.top_level? do
        path
      else
        path ++ [section.name]
      end

    Enum.concat([
      [
        %{
          anchor: anchor(schema_path),
          body: section.describe,
          title: title(schema_path),
          type: "DSL"
        }
      ],
      schema_search_data(section.schema, schema_path),
      Enum.flat_map(section.entities, &entity_search_data(&1, schema_path)),
      Enum.flat_map(section.sections, &section_search_data(&1, schema_path))
    ])
    |> Enum.map(fn search_item ->
      if section.top_level? do
        %{search_item | anchor: "#{section.name}-#{search_item.anchor}"}
      else
        search_item
      end
    end)
  end

  defp entity_search_data(entity, path) do
    Enum.concat([
      [
        %{
          anchor: anchor(path ++ [entity.name]),
          body: entity.describe,
          title: title(path ++ [entity.name]),
          type: "DSL"
        }
      ],
      schema_search_data(entity.schema, path ++ [entity.name]),
      Enum.flat_map(entity.entities, fn {_key, entities} ->
        Enum.flat_map(entities, fn nested_entity ->
          entity_search_data(nested_entity, path ++ [entity.name])
        end)
      end)
    ])
  end

  defp schema_search_data(schema, path) do
    Enum.flat_map(schema, fn {key, config} ->
      if config[:hide] do
        []
      else
        [
          %{
            anchor: anchor(path ++ [key]),
            body: config[:doc] || "",
            title: title(path ++ [key]),
            type: "DSL"
          }
        ]
      end
    end)
  end

  defp anchor(list), do: Enum.join(list, "-")
  defp title(list), do: Enum.join(list, ".")
end
