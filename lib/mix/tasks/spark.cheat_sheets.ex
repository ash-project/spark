defmodule Mix.Tasks.Spark.CheatSheets do
  @shortdoc """
  Creates a set of cheat sheets for each Extension provided

  You will want to include this task with the `--check` flag in your CI pipeline as well.
  """
  @moduledoc @shortdoc
  use Mix.Task

  def run(opts) do
    Mix.Task.run("compile")

    {opts, _} =
      OptionParser.parse!(opts,
        switches: [strip_prefix: :string, check: :boolean, extensions: :string, check: :string]
      )

    unless opts[:extensions] do
      raise "Must supply a comma separated list of extensions to generate a .formatter.exs for"
    end

    extensions =
      opts[:extensions]
      |> String.split(",")
      |> Enum.map(&Module.concat([&1]))
      |> Enum.uniq()

    if !opts[:check] do
      File.rm_rf!("documentation/dsls")
    end

    for extension <- extensions do
      cheat_sheet = Spark.CheatSheet.cheat_sheet(extension)
      File.mkdir_p!("documentation/dsls")
      extension_name = Spark.Mix.Helpers.extension_name(extension, opts)

      filename = "documentation/dsls/DSL:-#{extension_name}.cheatmd"

      if opts[:check] do
        if File.exists?(filename) && File.read!(filename) == cheat_sheet do
          Mix.shell().info("Cheat sheet for #{extension_name} is up to date")
        else
          raise """
          The cheat sheet for #{extension_name} is out of date. Please regenerate spark cheat sheets.
          """
        end
      else
        File.write!(filename, cheat_sheet)
      end
    end
  end
end
