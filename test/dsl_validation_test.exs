defmodule Spark.DslValidationTest do
  use ExUnit.Case, async: true

  @moduletag :capture_log

  describe "invalid DSL definitions" do
    test "entity nested definitions cannot be atoms" do
      error =
        assert_raise Spark.Error.DslError, fn ->
          defmodule InvalidNestedEntities do
            @moduledoc false

            defmodule Dsl do
              @moduledoc false

              @child %Spark.Dsl.Entity{
                name: :child,
                target: Spark.Test.Step,
                schema: []
              }

              @parent %Spark.Dsl.Entity{
                name: :parent,
                target: Spark.Test.Step,
                schema: [],
                # Invalid - should be an entity, not an atom
                entities: [child: :child_entity]
              }

              @section %Spark.Dsl.Section{
                name: :root,
                entities: [@parent]
              }

              use Spark.Dsl.Extension, sections: [@section]
            end

            use Spark.Dsl, default_extensions: [extensions: Dsl]
          end
        end

      assert error.message =~
               "nested entity 'child' must be an entity or list of entities, got: :child_entity"

      assert error.path == [:root, :parent, :child]
      assert error.module == Spark.DslValidationTest.InvalidNestedEntities.Dsl
    end

    test "entity nested definitions must be lists of entities or a single entity" do
      defmodule ValidNestedEntities do
        @moduledoc false

        defmodule Dsl do
          @moduledoc false

          @child %Spark.Dsl.Entity{
            name: :child,
            target: Spark.Test.Step,
            schema: []
          }

          @different_child %Spark.Dsl.Entity{
            name: :different_child,
            target: Spark.Test.Step,
            schema: []
          }

          @parent %Spark.Dsl.Entity{
            name: :parent,
            target: Spark.Test.Step,
            schema: [],
            # Both formats are valid
            entities: [child: @child, other_children: [@different_child]]
          }

          @section %Spark.Dsl.Section{
            name: :root,
            entities: [@parent]
          }

          use Spark.Dsl.Extension, sections: [@section]
        end

        use Spark.Dsl, default_extensions: [extensions: Dsl]
      end
    end
  end
end
