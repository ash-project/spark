defmodule Spark.Test.Contact do
  @moduledoc false

  defmodule Dsl do
    @moduledoc false

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

    use Spark.Dsl.Extension, sections: [@personal_details, @address]

    def explain(dsl_state) do
      """
      first_name: #{Spark.Test.Contact.Info.first_name(dsl_state)}
      last_name: #{Spark.Test.Contact.Info.last_name(dsl_state)}
      """
    end
  end

  use Spark.Dsl, default_extensions: [extensions: Dsl]
end
