defmodule Spark.Dsl.Section do
  @moduledoc """
  Declares a DSL section.

  A dsl section allows you to organize related configurations. All extensions
  configure sections, they cannot add DSL builders to the top level. This
  keeps things organized, and concerns separated.

  A section may have nested sections, which will be configured the same as other sections.
  Getting the options/entities of a section is done by providing a path, so you would
  use the nested path to retrieve that configuration. See `Spark.Dsl.Extension.get_entities/2`
  and `Spark.Dsl.Extension.get_opt/4`.

  A section may have entities, which are constructors that produce instances of structs.
  For more on entities, see `Spark.Dsl.Entity`.

  A section may also have a `schema`, which is a `NimbleOptions` schema. Spark will produce
  builders for those options, so that they may be configured. They are retrieved with
  `Spark.Dsl.Extension.get_opt/4`.

  To create a section that is available at the top level (i.e not  nested inside of its own name), use
  `top_level?: true`. Remember, however, that this has no effect on sections nested inside of other sections.

  For a full example, see `Spark.Dsl.Extension`.
  """
  defstruct [
    :name,
    imports: [],
    schema: [],
    describe: "",
    snippet: "",
    links: nil,
    examples: [],
    modules: [],
    top_level?: false,
    no_depend_modules: [],
    auto_set_fields: [],
    deprecations: [],
    entities: [],
    sections: [],
    docs: "",
    patchable?: false,
    referenced_as: nil,
  ]

  alias Spark.{
    Dsl.Entity,
    Dsl.Section,
    OptionsHelpers
  }

  @type t :: %Section{
          name: atom,
          imports: [module],
          schema: OptionsHelpers.schema(),
          describe: String.t(),
          snippet: String.t(),
          top_level?: boolean(),
          links: nil | Keyword.t([String.t()]),
          examples: [String.t()],
          modules: [atom],
          no_depend_modules: [atom],
          auto_set_fields: Keyword.t(any),
          entities: [Entity.t()],
          referenced_as: atom() | nil,
          sections: [Section.t()],
          docs: String.t(),
          patchable?: boolean
        }
end
