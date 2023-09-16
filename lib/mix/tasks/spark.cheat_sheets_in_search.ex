defmodule Mix.Tasks.Spark.CheatSheetsInSearch do
  @shortdoc "Includes generated cheat sheets in the search bar"
  @moduledoc @shortdoc
  use Mix.Task

  def run(opts) do
    Mix.Task.run("compile")

    {opts, _} =
      OptionParser.parse!(opts,
        switches: [strip_prefix: :string, check: :boolean, extensions: :string]
      )

    unless opts[:extensions] do
      raise "Must supply a comma separated list of extensions to generate a .formatter.exs for"
    end

    extensions =
      opts[:extensions]
      |> String.split(",")
      |> Enum.map(&Module.concat([&1]))
      |> Enum.uniq()

    with {:ok, search_data_file, search_data} <- search_data_file(),
         {:ok, sidebar_items_file, sidebar_items} <- sidebar_items_file() do
      {search_data, sidebar_items} =
        Enum.reduce(extensions, {search_data, sidebar_items}, fn extension, acc ->
          add_extension_to_search_data(extension, acc, opts)
        end)

      File.write!(search_data_file, "searchData=" <> Jason.encode!(search_data))
      File.write!(sidebar_items_file, "sidebarNodes=" <> Jason.encode!(sidebar_items))
    else
      {:error, error} -> raise error
    end
  end

  defp search_data_file do
    "doc/dist/search_data-*.js"
    |> Path.wildcard()
    |> Enum.at(0)
    |> case do
      nil ->
        {:error, "No search_data file found"}

      file ->
        case File.read!(file) do
          "searchData=" <> contents ->
            {:ok, file, Jason.decode!(contents)}

          _ ->
            {:error, "search data js file was malformed"}
        end
    end
  end

  defp sidebar_items_file do
    "doc/dist/sidebar_items-*.js"
    |> Path.wildcard()
    |> Enum.at(0)
    |> case do
      nil ->
        {:error, "No sidebar_items file found"}

      file ->
        case File.read!(file) do
          "sidebarNodes=" <> contents ->
            {:ok, file, Jason.decode!(contents)}

          _ ->
            {:error, "sidebar items js file was malformed"}
        end
    end
  end

  defp add_extension_to_search_data(extension, acc, opts) do
    extension_name = Spark.Mix.Helpers.extension_name(extension, opts)

    acc =
      Enum.reduce(extension.sections(), acc, fn section, acc ->
        add_section_to_search_data(extension_name, section, acc)
      end)

    Enum.reduce(
      extension.dsl_patches(),
      acc,
      fn %Spark.Dsl.Patch.AddEntity{
           section_path: section_path,
           entity: entity
         },
         acc ->
        add_entity_to_search_data(
          extension_name,
          entity,
          acc,
          section_path
        )
      end
    )
  end

  defp add_section_to_search_data(
         extension_name,
         section,
         {search_data, sidebar_items},
         path \\ []
       ) do
    search_data =
      add_search_item(
        search_data,
        %{
          "doc" => section.describe,
          "ref" =>
            "#{dsl_search_name(extension_name)}.html##{Enum.join(path ++ [section.name], "-")}",
          "title" => "#{extension_name}.#{Enum.join(path ++ [section.name], ".")}",
          "type" => "DSL"
        }
      )

    search_data =
      add_schema_to_search_data(
        search_data,
        extension_name,
        section.schema,
        path ++ [section.name]
      )

    acc =
      Enum.reduce(
        section.sections,
        {search_data, sidebar_items},
        &add_section_to_search_data(extension_name, &1, &2, path ++ [section.name])
      )

    Enum.reduce(
      section.entities,
      acc,
      &add_entity_to_search_data(extension_name, &1, &2, path ++ [section.name])
    )
  end

  defp add_entity_to_search_data(extension_name, entity, {search_data, sidebar_items}, path) do
    search_data =
      add_search_item(
        search_data,
        %{
          "doc" => entity.describe,
          "ref" =>
            "#{dsl_search_name(extension_name)}.html##{Enum.join(path ++ [entity.name], "-")}",
          "title" => "#{extension_name}.#{Enum.join(path ++ [entity.name], ".")}",
          "type" => "DSL"
        }
      )

    search_data =
      add_schema_to_search_data(
        search_data,
        extension_name,
        entity.schema,
        path ++ [entity.name]
      )

    entity.entities
    |> Enum.flat_map(&List.wrap(elem(&1, 1)))
    |> Enum.reduce(
      {search_data, sidebar_items},
      &add_entity_to_search_data(extension_name, &1, &2, path ++ [entity.name])
    )
  end

  defp add_schema_to_search_data(
         search_data,
         extension_name,
         schema,
         path
       ) do
    Enum.reduce(schema || [], search_data, fn {key, config}, search_data ->
      add_search_item(
        search_data,
        %{
          "doc" => config[:doc] || "",
          "ref" => "#{dsl_search_name(extension_name)}.html##{Enum.join(path ++ [key], "-")}",
          "title" => "#{extension_name}.#{Enum.join(path ++ [key], ".")}",
          "type" => "DSL"
        }
      )
    end)
  end

  defp dsl_search_name(extension_name) do
    ("dsl-" <> extension_name) |> String.split(".") |> Enum.map_join("-", &String.downcase/1)
  end

  defp add_search_item(search_data, item) do
    item = Map.update!(item, "title", &String.trim(&1 || ""))
    Map.update!(search_data, "items", &Enum.uniq([item | &1]))
  end
end
