defmodule Spark.Test.Recursive do
  @moduledoc false
  defmodule Dsl do
    @moduledoc false
    defmodule Impl do
      use Spark

      entity do
        name(:atom)
        target(Spark.Test.Atom)
        args([:name])

        schema do
          field :name do
            type(:atom)
            required(true)
          end
        end
      end

      entity do
        name(:step)
        target(Spark.Test.Step)
        args([:name])
        recursive_as(:steps)
        entities(steps: :atom)

        schema do
          field :name do
            type(:atom)
            required(true)
          end

          field :number do
            type(:integer)
            required(false)
          end
        end
      end

      entity do
        name(:special_step)
        target(Spark.Test.Step)
        args([:name])
        recursive_as(:steps)
        entities(steps: :atom)

        schema do
          field :name do
            type(:atom)
            required(true)
          end

          field :number do
            type(:integer)
            required(false)
          end
        end
      end

      section do
        name(:steps)
        entities([:step, :special_step, :atom])
      end
    end

    sections = Spark.load(Impl)

    use Spark.Dsl.Extension,
      sections: sections
  end

  use Spark.Dsl, default_extensions: [extensions: Dsl]
end
