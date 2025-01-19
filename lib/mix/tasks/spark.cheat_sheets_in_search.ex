# if Code.ensure_loaded?(Jason) do
defmodule Mix.Tasks.Spark.CheatSheetsInSearch do
  @shortdoc "Includes generated cheat sheets in the search bar"
  @moduledoc @shortdoc
  use Mix.Task

  def run(_opts) do
    IO.warn(
      "Please switch to using `Spark.Docs.search_data_for/1`, this task no longer does anything"
    )
  end
end
