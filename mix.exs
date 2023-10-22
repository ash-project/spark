defmodule Spark.MixProject do
  use Mix.Project

  @version "1.1.48"

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

  defp extras() do
    "documentation/**/*.md"
    |> Path.wildcard()
    |> Enum.map(fn path ->
      title =
        path
        |> Path.basename(".md")
        |> String.split(~r/[-_]/)
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
        |> case do
          "F A Q" ->
            "FAQ"

          other ->
            other
        end

      {String.to_atom(path),
       [
         title: title
       ]}
    end)
  end

  defp groups_for_extras() do
    "documentation/*"
    |> Path.wildcard()
    |> Enum.map(fn folder ->
      name =
        folder
        |> Path.basename()
        |> String.split(~r/[-_]/)
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")

      {name, folder |> Path.join("**") |> Path.wildcard()}
    end)
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
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: [
        "DSLs and Extensions": ~r/(^Spark.Dsl|^Spark.OptionsHelpers)/,
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
      {:nimble_options, "~> 0.5 or ~> 1.0"},
      {:sourceror, "~> 0.1"},
      {:jason, "~> 1.4"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      # Dev/Test dependencies
      {:ex_doc, github: "elixir-lang/ex_doc", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.12.0", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.4.4", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:parse_trans, "3.3.0", only: [:dev, :test], override: true},
      {:elixir_sense, github: "elixir-lsp/elixir_sense", only: [:test, :dev, :docs]}
    ]
  end

  defp aliases do
    [
      sobelow: "sobelow --skip",
      credo: "credo --strict"
    ]
  end
end
