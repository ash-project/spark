defmodule TransfomerTest do
  use ExUnit.Case

  test "build_entity respects auto_set_fields" do
    defmodule Entity do
      defstruct [:set_automatically, :set_manually, :__identifier__]
    end

    defmodule Dsl do
      @entity %Spark.Dsl.Entity{
        name: :entity,
        target: Entity,
        schema: [
          set_automatically: [
            type: :boolean
          ],
          set_manually: [
            type: :boolean
          ]
        ],
        auto_set_fields: [set_automatically: true]
      }

      @section %Spark.Dsl.Section{
        name: :section,
        entities: [
          @entity
        ]
      }

      use Spark.Dsl.Extension, sections: [@section]
      use Spark.Dsl, default_extensions: [extensions: Dsl]
    end

    {:ok, entity} = Spark.Dsl.Transformer.build_entity(Dsl, [:section], :entity, [])

    assert entity.set_automatically == true
    assert entity.set_manually == nil
  end
end
