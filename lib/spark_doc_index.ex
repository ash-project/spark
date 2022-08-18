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
  def default_guide, do: "Example"

  @impl true
  def extensions, do: []

  @impl true
  @spec code_modules :: [{String.t(), list(module)}]
  def code_modules do
    [
      {"Resources",
       [
         Ash.Api,
         Ash.Resource.Info,
         Ash.Resource.Change,
         Ash.Resource.Change.Builtins,
         Ash.Resource.Validation,
         Ash.Resource.Validation.Builtins,
         Ash.Resource.Preparation,
         Ash.Resource.Preparation.Builtins,
         Ash.Filter.TemplateHelpers,
         Ash.Calculation,
         Ash.Resource.Calculation.Builtins,
         Ash.CodeInterface,
         Ash.Changeset,
         Ash.Query
       ]},
      {"Utilities",
       [
         Ash.Filter,
         Ash.Sort
       ]},
      {"Errors",
       [
         Ash.Error
       ]},
      {"Types",
       [
         Ash.Type,
         Ash.Type.Enum,
         Ash.Type.Atom,
         Ash.Type.Binary,
         Ash.Type.Boolean,
         Ash.Type.CiString,
         Ash.CiString,
         Ash.Type.Date,
         Ash.Type.Decimal,
         Ash.Type.DurationName,
         Ash.Type.Float,
         Ash.Type.Function,
         Ash.Type.Integer,
         Ash.Type.Map,
         Ash.Type.NaiveDatetime,
         Ash.Type.String,
         Ash.Type.Term,
         Ash.Type.Time,
         Ash.Type.UUID,
         Ash.Type.UrlEncodedBinary,
         Ash.Type.UtcDatetime,
         Ash.Type.UtcDatetimeUsec
       ]},
      {"DSLs and Extensions",
       [
         Spark.Dsl.Entity,
         Spark.Dsl.Extension,
         Spark.Dsl.Section,
         Spark.Dsl.Transformer
       ]},
      {"Documentation",
       [
         Spark.DocIndex
       ]}
    ]
  end
end
