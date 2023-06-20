defmodule Spark.Test.Recursive do
  @moduledoc false
  defmodule Dsl do
    @moduledoc false
    @atom %Spark.Dsl.Entity{
      name: :atom,
      target: Spark.Test.Atom,
      args: [:name],
      schema: [
        name: [
          type: :atom,
          required: true
        ]
      ]
    }

    @step %Spark.Dsl.Entity{
      name: :step,
      target: Spark.Test.Step,
      args: [:name],
      recursive_as: :steps,
      entities: [
        steps: [@atom]
      ],
      schema: [
        name: [
          type: :atom,
          required: true
        ],
        number: [
          type: :integer
        ]
      ]
    }

    @special_step %Spark.Dsl.Entity{
      name: :special_step,
      target: Spark.Test.Step,
      args: [:name],
      recursive_as: :steps,
      entities: [
        steps: [@atom]
      ],
      schema: [
        name: [
          type: :atom,
          required: true
        ],
        number: [
          type: :integer
        ]
      ]
    }

    @steps %Spark.Dsl.Section{
      name: :steps,
      entities: [@step, @special_step, @atom]
    }

    use Spark.Dsl.Extension,
      sections: [@steps]
  end

  use Spark.Dsl, default_extensions: [extensions: Dsl]
end
