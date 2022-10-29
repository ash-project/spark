defmodule Spark.Test.Contact do
  @moduledoc false

  @type t :: module

  defmodule Dsl do
    @moduledoc false

    @contact %Spark.Dsl.Section{
      name: :contact,
      schema: [
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
      defstruct [:name, :contacter, :default_message]
    end

    @preset %Spark.Dsl.Entity{
      name: :preset,
      args: [:name],
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

    @presets %Spark.Dsl.Section{
      name: :presets,
      entities: [
        @preset
      ]
    }

    use Spark.Dsl.Extension, sections: [@contact, @personal_details, @address, @presets]

    def explain(dsl_state) do
      """
      first_name: #{Spark.Test.Contact.Info.first_name(dsl_state)}
      last_name: #{Spark.Test.Contact.Info.last_name(dsl_state)}
      """
    end
  end

  use Spark.Dsl, default_extensions: [extensions: Dsl]
end
