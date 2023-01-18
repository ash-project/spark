import Config

config :spark, :enforce_spark_elixir_sense_behaviours?, true

if Mix.env() == :dev do
  config :git_ops,
    mix_project: Spark.MixProject,
    changelog_file: "CHANGELOG.md",
    repository_url: "https://github.com/ash-project/spark",
    # Instructs the tool to manage your mix version in your `mix.exs` file
    # See below for more information
    manage_mix_version?: true,
    # Instructs the tool to manage the version in your README.md
    # Pass in `true` to use `"README.md"` or a string to customize
    manage_readme_version: "documentation/tutorials/get-started-with-spark.md",
    version_tag_prefix: "v"
end
