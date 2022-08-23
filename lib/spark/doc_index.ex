defmodule Spark.DocIndex do
  @moduledoc """
  A module for creating an index of documentation for a library. Can be rendered by tools like `ash_hq`.

  There is a small template syntax available in any documentation.
  The template syntax will link to the user's currently selected
  version for the relevant library.

  All templates should be wrapped in double curly braces, e.g `{{}}`.

  ## Links to other documentation

  `{{link:library:item_type:name}}`

  For example:

  `{{link:ash:guide:Attributes}}` might be transformed to `<a href="/docs/guides/ash/topics/attributes.md">Attributes</a>`

  ## Mix dependencies

  `{{mix_dep:library}}`

  For example:

  `{{mix_dep:ash}}` might be transformed to `{:ash, "~> 1.5"}`
  """

  @type extension :: %{
          optional(:module) => module,
          optional(:target) => String.t(),
          optional(:default_for_target?) => boolean,
          :name => String.t(),
          :type => String.t()
        }

  @type guide :: %{
          name: String.t(),
          path: String.t(),
          category: String.t() | nil,
          route: String.t() | nil
        }

  @callback extensions() :: list(extension())
  @callback for_library() :: String.t()
  @callback guides() :: list(guide())
  @callback code_modules() :: [{String.t(), list(module())}]

  defmacro __using__(opts) do
    quote bind_quoted: [guides_from: opts[:guides_from]] do
      @behaviour Spark.DocIndex

      @guides guides_from
              |> Path.wildcard()
              |> Enum.map(fn path ->
                path
                |> Path.split()
                |> Enum.reverse()
                |> Enum.take(2)
                |> Enum.reverse()
                |> case do
                  [category, file] ->
                    %{
                      name: Spark.DocIndex.to_name(Path.rootname(file)),
                      category: Spark.DocIndex.to_name(category),
                      path: path,
                      route: "#{Spark.DocIndex.to_path(category)}/#{Spark.DocIndex.to_path(file)}"
                    }
                end
              end)

      if guides_from do
        @impl Spark.DocIndex
        # sobelow_skip ["Traversal.FileModule"]
        def guides do
          @guides
        end

        defoverridable guides: 0
      end
    end
  end

  def find_undocumented_items(doc_index) do
    Enum.each(doc_index.extensions(), fn extension ->
      Enum.each(
        extension.module.sections(),
        &find_undocumented_in_section(&1, [inspect(extension.module)])
      )
    end)
  end

  defp find_undocumented_in_section(section, path) do
    if !section.links do
      IO.warn("No links for #{Enum.reverse(path) |> Enum.join(".")}.#{section.name}")
    end

    find_undocumented_in_schema(section.schema, [section.name | path])
    Enum.each(section.sections, &find_undocumented_in_section(&1, [section.name | path]))
    Enum.each(section.entities, &find_undocumented_in_entity(&1, [section.name | path]))
  end

  defp find_undocumented_in_entity(entity, path) do
    if !entity.links do
      IO.warn("No links for #{Enum.reverse(path) |> Enum.join(".")}.#{entity.name}")
    end

    find_undocumented_in_schema(entity.schema, [entity.name | path])

    Enum.each(entity.entities, fn {_key, entities} ->
      Enum.each(entities, &find_undocumented_in_entity(&1, [entity.name | path]))
    end)
  end

  defp find_undocumented_in_schema(schema, path) do
    Enum.each(schema, fn {key, opts} ->
      if !opts[:links] do
        IO.warn("No links for #{Enum.reverse(path) |> Enum.join(".")}.#{key}")
      end

      if !opts[:doc] do
        IO.warn("No doc for #{Enum.reverse(path) |> Enum.join(".")}.#{key}")
      end
    end)
  end

  # sobelow_skip ["Traversal.FileModule"]
  def read!(app, path) do
    app
    |> :code.priv_dir()
    |> Path.join(path)
    |> File.read!()
  end

  def to_name(string) do
    string
    |> String.split(~r/[-_]/, trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  def to_path(string) do
    string
    |> String.split(~r/\s/, trim: true)
    |> Enum.join("-")
    |> String.downcase()
  end
end
