defmodule Spark.MixProject do
  use Mix.Project

  @version "2.1.22"

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
        "DSLs and Extensions": ~r/(^Spark.Dsl|^Spark.OptionsHelpers|^Spark.Options)/,
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
      {:sourceror, "~> 1.0"},
      {:jason, "~> 1.4"},
      # Dev/Test dependencies
      {:ex_doc, "~> 0.32.0", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.12", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.5", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:elixir_sense, github: "elixir-lsp/elixir_sense", only: [:test, :dev, :docs]},
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
