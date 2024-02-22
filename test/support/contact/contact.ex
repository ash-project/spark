defmodule Spark.Test.Contact do
  @moduledoc false

  @type t :: module

  defmodule Dsl do
    @moduledoc false

    @contact %Spark.Dsl.Section{
      name: :contact,
      no_depend_modules: [:module],
      schema: [
        module: [
          type: :atom,
          doc: "A module"
        ],
        contacter: [
          doc: "A function that wil contact this person with a message",
          type:
            {:spark_function_behaviour, Spark.Test.Contact.Contacter,
             {Spark.Test.Contact.Contacter.Function, 1}}
        ]
      ]
    }

    @personal_details %Spark.Dsl.Section{
      name: :personal_details,
      schema: [
        first_name: [
          type: :string,
          doc: "The first name of the contact",
          required: true
        ],
        last_name: [
          type: :string,
          doc: "The last name of the contact"
        ],
        contact: [
          type: :string,
          doc: "Added to incur a conflict between this and the `contact` top level section."
        ]
      ]
    }

    @address %Spark.Dsl.Section{
      name: :address,
      schema: [
        street: [
          type: :string,
          doc: "The street address"
        ]
      ]
    }

    defmodule Preset do
      @moduledoc false
      defstruct [
        :name,
        :contacter,
        :default_message,
        :singleton,
        :__identifier__,
        special?: false
      ]
    end

    defmodule Singleton do
      @moduledoc false
      defstruct [:value]
    end

    @singleton %Spark.Dsl.Entity{
      name: :singleton,
      args: [:value],
      target: Singleton,
      schema: [
        value: [
          type: :any
        ]
      ]
    }

    @preset_with_fn_arg %Spark.Dsl.Entity{
      name: :preset_with_fn_arg,
      args: [:name, :contacter],
      target: Preset,
      schema: [
        name: [
          type: :atom
        ],
        default_message: [
          type: :string
        ],
        contacter: [
          type:
            {:spark_function_behaviour, Spark.Test.Contact.Contacter,
             {Spark.Test.Contact.Contacter.Function, 1}}
        ]
      ]
    }

    @preset %Spark.Dsl.Entity{
      name: :preset,
      args: [:name],
      target: Preset,
      identifier: :name,
      entities: [
        singleton: [@singleton]
      ],
      singleton_entity_keys: [:singleton],
      schema: [
        name: [
          type: :atom
        ],
        default_message: [
          type: :string
        ],
        contacter: [
          type:
            {:spark_function_behaviour, Spark.Test.Contact.Contacter,
             {Spark.Test.Contact.Contacter.Function, 1}}
        ]
      ]
    }

    @preset_with_quoted %Spark.Dsl.Entity{
      name: :preset_with_quoted,
      args: [:name],
      target: Preset,
      schema: [
        name: [
          type: :quoted
        ],
        default_message: [
          type: :quoted
        ]
      ]
    }

    @preset_with_optional %Spark.Dsl.Entity{
      name: :preset_with_optional,
      args: [{:optional, :name, :atom}, {:optional, :default_message}],
      target: Preset,
      schema: [
        name: [
          type: :atom,
          required: true
        ],
        default_message: [
          type: {:or, [:string, {:in, [nil]}]}
        ],
        contacter: [
          type:
            {:spark_function_behaviour, Spark.Test.Contact.Contacter,
             {Spark.Test.Contact.Contacter.Function, 1}}
        ]
      ]
    }

    @preset_with_snippet %Spark.Dsl.Entity{
      name: :preset_with_snippet,
      args: [:name],
      target: Preset,
      snippet: "preset_with_snippet ${1::doc_brown}",
      schema: [
        name: [
          type: :atom,
          required: true
        ]
      ]
    }

    @presets %Spark.Dsl.Section{
      name: :presets,
      entities: [
        @preset,
        @preset_with_fn_arg,
        @preset_with_optional,
        @preset_with_quoted,
        @preset_with_snippet
      ]
    }

    @awesome_status %Spark.Dsl.Section{
      name: :awesome?,
      schema: [
        awesome?: [
          type: :boolean,
          required: true
        ]
      ]
    }

    use Spark.Dsl.Extension,
      sections: [@contact, @personal_details, @address, @presets, @awesome_status],
      verifiers: [Spark.Test.Contact.Verifiers.VerifyNotGandalf]

    def explain(dsl_state) do
      """
      * first_name: #{Spark.Test.Contact.Info.first_name(dsl_state)}
      * last_name: #{Spark.Test.Contact.Info.last_name(dsl_state)}
      """
    end
  end

  use Spark.Dsl, default_extensions: [extensions: Dsl]

  defmacro __using__(opts) do
    super(opts)
  end

  def explain(_dsl_state, _opts) do
    "Here is an explanation"
  end
end
