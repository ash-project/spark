defmodule Spark.Test.TopLevel do
  @moduledoc false
  defmodule Dsl do
    @moduledoc false
    defmodule Impl do
      @moduledoc false
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
        entities(steps: [])

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

        entities(steps: [])

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
        name(:nested_section)

        schema do
          field :bar do
            type(:integer)
            doc("Some documentation")
            required(false)
          end
        end
      end

      section do
        name(:steps)
        sections([:nested_section])

        schema do
          field :foo do
            type(:integer)
            doc("Some documentation")
            required(false)
          end
        end

        entities([:step, :special_step, :atom])
        top_level?(true)
      end
    end

    sections = Spark.load(Impl, [:steps])

    use Spark.Dsl.Extension,
      sections: sections
  end

  use Spark.Dsl, default_extensions: [extensions: Dsl]
end
