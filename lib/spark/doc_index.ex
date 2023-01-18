defmodule Spark.DocIndex do
  @moduledoc """
  A module for creating an index of documentation for a library. Can be rendered by tools like `ash_hq`.

  This has been deprecated, but remains for backwards compatibility
  """

  @type extension :: %{
          optional(:module) => module,
          optional(:target) => String.t(),
          optional(:default_for_target?) => boolean,
          :name => String.t(),
          :type => String.t()
        }

  @type guide :: %{
          :name => String.t(),
          :path => String.t(),
          :category => String.t() | nil,
          :route => String.t() | nil,
          optional(:basename) => String.t()
        }

  @callback extensions() :: list(extension())
  @callback for_library() :: String.t()
  @callback guides() :: list(guide())
  @callback code_modules() :: [{String.t() | atom, list(module()) | Regex.t()}]
  @callback mix_tasks() :: [{String.t(), list(module())}]

  @optional_callbacks code_modules: 0, mix_tasks: 0

  defmacro __using__(opts) do
    quote generated: true,
          bind_quoted: [guides_from: opts[:guides_from], guide_order: opts[:guide_order]] do
      @behaviour Spark.DocIndex

      @guides if guides_from,
                do:
                  guides_from
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
                          basename: Path.basename(file),
                          category: Spark.DocIndex.to_name(category),
                          path: path,
                          route:
                            "#{Spark.DocIndex.to_path(category)}/#{Spark.DocIndex.to_path(file)}"
                        }
                    end
                  end)
                  |> Enum.group_by(& &1.category)
                  |> Enum.flat_map(fn {category, guides} ->
                    order = guide_order[category] || guide_order[String.to_atom(category)] || []

                    Enum.sort_by(guides, fn guide ->
                      {Enum.find_index(order, &(&1 == guide.basename)), guide.name}
                    end)
                  end)

      def default_guide do
        guides = guides()

        guides
        |> Enum.find(fn guide ->
          String.contains?(guide.path, "started")
        end)
        |> Kernel.||(Enum.at(guides, 0))
      end

      if guides_from do
        @impl Spark.DocIndex
        # sobelow_skip ["Traversal.FileModule"]
        def guides do
          @guides
        end

        defoverridable guides: 0, default_guide: 0
      else
        defoverridable default_guide: 0
      end
    end
  end

  @doc "This has been deprecated and will be removed in future releases"
  def render_replacements(docs, contexts \\ %{}, callback)
  def render_replacements(nil, _, _), do: ""

  def render_replacements(docs, contexts, callback) do
    Enum.reduce(contexts, docs, fn {name, regex}, docs ->
      String.replace(docs, regex, fn contents ->
        contents
        |> render_links(callback, name)
        |> render_mix_deps(callback, name)
      end)
    end)
    |> render_links(callback, nil)
    |> render_mix_deps(callback, nil)
  end

  defp render_mix_deps(docs, callback, context) do
    docs
    |> String.replace(~r/____mix_dep_(.*)____/, fn text ->
      library =
        text
        |> String.trim_leading("____mix_dep_")
        |> String.trim_trailing("____")

      try do
        callback.(:mix_dep, %{text: text, library: library}, context)
      rescue
        e ->
          IO.warn(
            "Invalid link `#{text}`: #{Exception.format(:error, e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
          )

          text
      end
    end)
    |> String.replace(~r/{{mix_dep:.*}}/, fn text ->
      try do
        "{{mix_dep:" <> library = String.trim_trailing(text, "}}")
        callback.(:mix_dep, %{text: text, library: library}, context)
      rescue
        e ->
          IO.warn(
            "Invalid link `#{text}`: #{Exception.format(:error, e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
          )

          text
      end
    end)
  end

  def render_links(docs, callback, context) do
    String.replace(docs, ~r/{{link:[^}]*}}/, fn text ->
      try do
        "{{link:" <> rest = String.trim_trailing(text, "}}")

        [library, type | rest] = String.split(rest, ":")

        {item, type, name_override} =
          case rest do
            [] ->
              case String.split(type, "|") do
                [type] ->
                  {nil, type, nil}

                [type, name] ->
                  {nil, type, name}
              end

            rest ->
              case String.split(List.last(rest), "|") do
                [item] ->
                  {item, type, nil}

                [item, name] ->
                  {item, type, name}
              end
          end

        callback.(
          :link,
          %{text: text, library: library, type: type, item: item, name_override: name_override},
          context
        )
      rescue
        e ->
          IO.warn(
            "Invalid link `#{text}`: #{Exception.format(:error, e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
          )

          text
      end
    end)
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
