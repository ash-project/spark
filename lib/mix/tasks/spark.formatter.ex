defmodule Mix.Tasks.Spark.Formatter do
  @shortdoc "Manages a variable called `spark_locals_without_parens` in the .formatter.exs from a list of DSL extensions."
  @moduledoc @shortdoc
  use Mix.Task

  @spec run(term) :: no_return
  def run(opts) do
    Mix.Task.run("compile")
    {opts, []} = OptionParser.parse!(opts, strict: [check: :boolean, extensions: :string])

    unless opts[:extensions] do
      raise "Must supply a comma separated list of extensions to generate a .formatter.exs for"
    end

    locals_without_parens =
      opts[:extensions]
      |> String.split(",")
      |> Enum.flat_map(fn extension ->
        extension_mod = Module.concat([extension])

        case Code.ensure_compiled(extension_mod) do
          {:module, _module} -> :ok
          other -> raise "Error ensuring extension compiled #{inspect(other)}"
        end

        all_entity_builders(extension_mod.sections())
      end)
      |> Enum.uniq()
      |> Enum.sort()

    contents = File.read!(".formatter.exs")

    {_ast, spark_locals_without_parens} =
      contents
      |> Sourceror.parse_string!()
      |> Macro.prewalk(
        nil,
        fn
          {:=, _,
           [
             {:spark_locals_without_parens, _, _},
             right
           ]} = ast,
          _acc ->
            {ast, right}

          ast, acc ->
            {ast, acc}
        end
      )

    if !spark_locals_without_parens do
      raise "Add `spark_locals_without_parens = []` to your .formatter.exs and run this again to populate the list."
    end

    new_contents =
      contents
      |> Sourceror.patch_string([
        %{
          range: Sourceror.get_range(spark_locals_without_parens, include_comments: true),
          change: Sourceror.to_string(locals_without_parens, opts)
        }
      ])
      |> Code.format_string!()

    contents_with_newline = [new_contents, "\n"]

    if opts[:check] do
      if contents != IO.iodata_to_binary(contents_with_newline) do
        raise """
        .formatter.exs is not up to date!

        Run the following command and commit the result:

        mix spark.formatter --extensions #{opts[:extensions]}
        """
      else
        IO.puts("The current .formatter.exs is correct")
      end
    else
      File.write!(".formatter.exs", contents_with_newline)
    end
  end

  defp all_entity_builders(sections) do
    Enum.flat_map(sections, fn section ->
      Enum.concat([
        all_entity_option_builders(section),
        section_option_builders(section),
        section_entity_builders(section)
      ])
    end)
  end

  defp section_entity_builders(section) do
    Enum.flat_map(section.entities(), fn entity ->
      entity_builders(entity)
    end) ++ all_entity_builders(section.sections())
  end

  defp entity_builders(entity) do
    arg_count = Enum.count(entity.args)

    [{entity.name, arg_count}, {entity.name, arg_count + 1}] ++
      flat_map_nested_entities(entity, &entity_builders/1)
  end

  defp all_entity_option_builders(section) do
    Enum.flat_map(section.entities, fn entity ->
      entity_option_builders(entity)
    end)
  end

  defp entity_option_builders(entity) do
    entity.schema
    |> Keyword.drop(entity.args)
    |> Enum.map(fn {key, _schema} ->
      {key, 1}
    end)
    |> Kernel.++(flat_map_nested_entities(entity, &entity_option_builders/1))
  end

  defp section_option_builders(section) do
    Enum.map(section.schema, fn {key, _} ->
      {key, 1}
    end)
  end

  defp flat_map_nested_entities(entity, mapper) do
    Enum.flat_map(entity.entities, fn {_, nested_entities} ->
      nested_entities
      |> List.wrap()
      |> Enum.flat_map(fn nested_entity ->
        mapper.(nested_entity)
      end)
    end)
  end
end
