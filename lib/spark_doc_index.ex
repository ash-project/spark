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
  @spec code_modules :: [{String.t(), list(module)}]
  def code_modules do
    [
      {"DSLs and Extensions",
       [
         Spark.Dsl,
         Spark.Dsl.Entity,
         Spark.Dsl.Extension,
         Spark.Dsl.Section,
         Spark.Dsl.Transformer
       ]},
      {"Documentation",
       [
         Spark.DocIndex
       ]},
      {"Errors",
       [
         Spark.Error.DslError
       ]}
    ]
  end
end
