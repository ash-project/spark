defmodule Mix.Tasks.Spark.Install do
  @moduledoc "Installs spark by adding the `Spark.Formatter` plugin, and providing a basic configuration for it in `config.exs`."
  @shortdoc @moduledoc
  use Igniter.Mix.Task

  def igniter(igniter, _argv) do
    igniter
    |> Igniter.Formatter.add_formatter_plugin(Spark.Formatter)
    |> Igniter.Config.configure(
      "config.exs",
      :spark,
      [:formatter, :remove_parens?],
      true,
      &{:ok, &1}
    )
  end
end
