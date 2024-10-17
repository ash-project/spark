defmodule Spark.MixProject do
  use Mix.Project

  @version "2.2.35"

  @description "Generic tooling for building DSLs"

  def project do
    [
      app: :spark,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      description: @description,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      source_url: "https://github.com/ash-project/spark",
      homepage_url: "https://github.com/ash-project/spark",
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  defp elixirc_paths(:test) do
    elixirc_paths(:prod) ++ ["test/support"]
  end

  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    # The main page in the docs
    [
      main: "get-started-with-spark",
      source_ref: "v#{@version}",
      extra_section: "GUIDES",
      before_closing_head_tag: fn type ->
        if type == :html do
          """
          <script>
            if (location.hostname === "hexdocs.pm") {
              var script = document.createElement("script");
              script.src = "https://plausible.io/js/script.js";
              script.setAttribute("defer", "defer")
              script.setAttribute("data-domain", "ashhexdocs")
              document.head.appendChild(script);
            }
          </script>
          """
        end
      end,
      spark: [
        mix_tasks: [
          Formatting: [
            Mix.Tasks.Spark.Formatter
          ]
        ]
      ],
      extras: [
        "documentation/how_to/upgrade-to-2.0.md",
        "documentation/how_to/writing-extensions.md",
        "documentation/how_to/split-up-large-dsls.md",
        "documentation/tutorials/get-started-with-spark.md"
      ],
      groups_for_extras: [
        "How To": ~r/documentation\/how_to/,
        Tutorials: ~r/documentation\/tutorials/
      ],
      groups_for_modules: [
        "DSLs and Extensions": ~r/^Spark.Dsl/,
        Options: ~r/^Spark.Options/,
        Errors: [Spark.Error.DslError],
        Internals: ~r/.*/
      ]
    ]
  end

  defp package do
    [
      name: :spark,
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*
                CHANGELOG* documentation),
      links: %{
        GitHub: "https://github.com/ash-project/spark"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:sourceror, "~> 1.2"},
      # in 3.x, make this dependency optional
      {:jason, "~> 1.4"},
      {:igniter, "~> 0.2 and >= 0.3.64"},
      # Dev/Test dependencies
      {:benchee, "~> 1.3", only: [:dev, :test]},
      {:eflame, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.32", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.12", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.5", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:elixir_sense,
       github: "zachdaniel/elixir_sense",
       only: [:dev, :test, :docs],
       ref: "572c81c4046e12857b734abc28aa14b7d1f6f595"},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      sobelow: "sobelow --skip",
      credo: "credo --strict"
    ]
  end
end
