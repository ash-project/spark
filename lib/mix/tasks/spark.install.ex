if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Spark.Install do
    @moduledoc "Installs spark by adding the `Spark.Formatter` plugin, and providing a basic configuration for it in `config.exs`."
    @shortdoc @moduledoc

    use Igniter.Mix.Task

    @impl true
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        schema: [
          yes: :boolean
        ],
        aliases: [
          y: :yes
        ]
      }
    end

    @impl true
    def igniter(igniter) do
      igniter
      |> Igniter.Project.Formatter.add_formatter_plugin(Spark.Formatter)
      |> Igniter.Project.Deps.add_dep({:sourceror, "~> 1.7", only: [:dev, :test]},
        yes?: igniter.args.options[:yes],
        notify_on_present?: false
      )
      |> Igniter.Project.Config.configure(
        "config.exs",
        :spark,
        [:formatter, :remove_parens?],
        true,
        updater: &{:ok, &1}
      )
    end
  end
else
  defmodule Mix.Tasks.Spark.Install do
    @moduledoc "Installs spark by adding the `Spark.Formatter` plugin, and providing a basic configuration for it in `config.exs`."
    @shortdoc @moduledoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'spark.install' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
