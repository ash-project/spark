defmodule Mix.Tasks.Spark.CheatSheets do
  @shortdoc """
  Creates a set of cheat sheets for each Extension provided

  You may want to remove the generated files afterwards, with `fn _ -> File.rm_rf!("documentation/dsls") end` at the end of your `mix docs` alias.

  For example:

  ```elixir
  defp aliases do
    [
      docs: [
        "spark.cheat_sheets",
        "docs",
        "spark.cheat_sheets_in_search",
        fn _ ->
          File.rm_rf!("documentation/dsls")
        end
      ]
    ]
  end
  ```
  """
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

    File.rm_rf!("documentation/dsls")

    for extension <- extensions do
      cheat_sheet = Spark.CheatSheet.cheat_sheet(extension)
      File.mkdir_p!("documentation/dsls")
      extension_name = Spark.Mix.Helpers.extension_name(extension, opts)
      File.write!("documentation/dsls/DSL:-#{extension_name}.cheatmd", cheat_sheet)
    end
  end
end
