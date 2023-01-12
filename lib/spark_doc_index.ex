defmodule Spark.SparkDocIndex do
  @moduledoc """
  Stores the documentation
  """

  use Spark.DocIndex,
    otp_app: :ash,
    guides_from: [
      "documentation/**/*.md"
    ]

  @impl true
  @spec for_library() :: String.t()
  def for_library, do: "spark"

  @impl true
  def extensions, do: []

  @impl true
  @spec mix_tasks() :: [{String.t(), list(module)}]
  def mix_tasks do
    [
      {
        "Formatting",
        [
          Mix.Tasks.Spark.Formatter
        ]
      }
    ]
  end

  @impl true
  def code_modules do
    [
      "DSLs and Extensions": ~r/(^Spark.Dsl|^Spark.OptionsHelpers)/,
      Documentation: [Spark.DocIndex],
      Errors: [Spark.Error.DslError]
    ]
  end
end
