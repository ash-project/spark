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
  end

  use Spark.Dsl, default_extensions: [extensions: Dsl]
end
