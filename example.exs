Mix.install([{:spark, path: "."}], force: true)

defmodule CustomDsl do
  defmodule MyEntity do
    defstruct [:name]
  end

  defmodule OtherEntity do
    defstruct [:name, :value]
  end

  defmodule Dsl do
    use Spark

    entity do
      name(:my_entity)
      target(MyEntity)

      schema do
        field :name do
          type(:any)
          required(true)
        end
      end
    end

    entity do
      name(:other_entity)
      target(OtherEntity)

      schema do
        field :name do
          type(:atom)
          required(true)
        end

        field :value do
          type(:any)
          required(true)
        end
      end
    end

    section do
      name(:my_section)
      entities([:my_entity, :other_entity])
    end
  end

  complete_sections = Spark.load(Dsl)
  use Spark.Dsl.Extension, sections: complete_sections
end

defmodule CustomDsl.Use do
  use Spark.Dsl,
    default_extensions: [extensions: CustomDsl]
end

defmodule Try do
  use CustomDsl.Use

  my_section do
    my_entity do
      name(:hello)
    end

    other_entity do
      name(:world)
      value(2)
    end
  end
end

IO.inspect(Spark.Dsl.Extension.get_entities(Try, [:my_section]))
