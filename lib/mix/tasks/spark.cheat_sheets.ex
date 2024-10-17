defmodule Mix.Tasks.Spark.CheatSheets do
  @shortdoc "Creates cheat sheets for each Extension provided. Useful for CI with `--check` flag."
  @moduledoc @shortdoc
  use Mix.Task

  def run(opts) do
    Mix.Task.run("compile")

    {opts, _} =
      OptionParser.parse!(opts,
        switches: [strip_prefix: :string, check: :boolean, extensions: :string, check: :string]
      )

    extensions =
      opts
      |> Keyword.get(:extensions, "")
      |> Kernel.||("")
      |> String.split(",")
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&Module.concat([&1]))
      |> Enum.uniq()

    if !opts[:check] do
      File.rm_rf!("documentation/dsls")
    end

    Application.ensure_all_started(:rewrite)

    Igniter.new()
    |> Igniter.update_elixir_file("mix.exs", fn zipper ->
      Igniter.Code.Common.update_all_matches(zipper, &Igniter.Code.String.string?/1, fn zipper ->
        Igniter.Code.String.update_string(zipper, fn
          "DSL:-" <> rest ->
            {:ok, "DSL-" <> rest}

          "documentation/dsls/DSL:-" <> rest ->
          {:ok, "documentation/dsls/DSL-" <> rest}

          other ->
            {:ok, other}
        end)
      end)
    end)
    |> Igniter.do_or_dry_run(yes: true)

    for extension <- extensions do
      cheat_sheet = Spark.CheatSheet.cheat_sheet(extension)
      File.mkdir_p!("documentation/dsls")
      extension_name = Spark.Mix.Helpers.extension_name(extension, opts)

      filename = "documentation/dsls/DSL-#{extension_name}.md"

      if opts[:check] do
        if File.exists?(filename) && String.trim(File.read!(filename)) == String.trim(cheat_sheet) do
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
