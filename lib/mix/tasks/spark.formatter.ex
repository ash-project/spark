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

    extensions =
      opts[:extensions]
      |> String.split(",")
      |> Enum.map(&Module.concat([&1]))

    locals_without_parens =
      Enum.flat_map(extensions, fn extension_mod ->
        case Code.ensure_compiled(extension_mod) do
          {:module, _module} -> :ok
          other -> raise "Error ensuring extension compiled #{inspect(other)}"
        end

        all_entity_builders_everywhere(extension_mod.sections(), extensions)
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
        Sourceror.Patch.new(
          Sourceror.get_range(spark_locals_without_parens, include_comments: true),
          Sourceror.to_string(locals_without_parens, opts)
        )
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

  def all_entity_builders_everywhere(sections, extensions, path \\ []) do
    sections
    |> Enum.flat_map(fn section ->
      all_entity_builders_everywhere(
        section.sections,
        extensions,
        path ++ [section.name]
      )
    end)
    |> Enum.concat(Spark.Formatter.all_entity_builders(sections, extensions, path))
  end
end
