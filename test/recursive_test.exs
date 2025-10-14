# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.RecursiveTest do
  use ExUnit.Case

  alias Spark.Test.Recursive.Info

  test "recursive DSLs can be defined without recursive elements" do
    defmodule Simple do
      use Spark.Test.Recursive

      steps do
        step(:foo)
      end
    end

    assert [%Spark.Test.Step{name: :foo, steps: []}] = Info.steps(Simple)
  end

  test "recursive DSLs can recurse" do
    defmodule OneRecurse do
      use Spark.Test.Recursive

      steps do
        step :foo do
          step(:bar)
        end
      end
    end

    assert [
             %Spark.Test.Step{
               name: :foo,
               steps: [
                 %Spark.Test.Step{name: :bar, steps: []}
               ]
             }
           ] = Info.steps(OneRecurse)
  end

  test "recursive DSLs can be mixed" do
    defmodule MixedRecurse do
      use Spark.Test.Recursive

      steps do
        step :foo do
          special_step(:special)
          atom(:bar)
        end
      end
    end

    assert [
             %Spark.Test.Step{
               name: :foo,
               steps: [
                 %Spark.Test.Step{name: :special, steps: []},
                 %Spark.Test.Atom{name: :bar}
               ]
             }
           ] = Info.steps(MixedRecurse)
  end

  test "recursive DSLs that share entities don't collide" do
    defmodule MixedRecurseSharedEntity do
      use Spark.Test.Recursive

      steps do
        step :foo do
          special_step(:special) do
            atom(:bar)
          end

          atom(:bar)
        end
      end
    end

    assert [
             %Spark.Test.Step{
               name: :foo,
               steps: [
                 %Spark.Test.Step{
                   name: :special,
                   steps: [
                     %Spark.Test.Atom{name: :bar}
                   ]
                 },
                 %Spark.Test.Atom{name: :bar}
               ]
             }
           ] = Info.steps(MixedRecurseSharedEntity)
  end

  test "recursive DSLs that share options don't collide" do
    defmodule OptionsDontCollide do
      use Spark.Test.Recursive

      steps do
        step :foo do
          number(10)

          special_step(:special) do
            number(12)
          end
        end
      end
    end

    assert [
             %Spark.Test.Step{
               name: :foo,
               number: 10,
               steps: [
                 %Spark.Test.Step{
                   name: :special,
                   number: 12
                 }
               ]
             }
           ] = Info.steps(OptionsDontCollide)
  end

  test "recursive DSLs can share entities and be deeply nested" do
    defmodule DeeplyNested do
      use Spark.Test.Recursive

      steps do
        step :foo do
          special_step(:special) do
            atom(:bar)

            step :step_in_special do
              step :step_in_special2 do
                atom(:bar)
              end
            end
          end

          step :not_special do
            special_step(:special2) do
              atom(:bar)
            end
          end
        end
      end
    end

    assert [
             %Spark.Test.Step{
               name: :foo,
               steps: [
                 %Spark.Test.Step{
                   name: :special,
                   steps: [
                     %Spark.Test.Atom{name: :bar},
                     %Spark.Test.Step{
                       name: :step_in_special,
                       steps: [
                         %Spark.Test.Step{
                           name: :step_in_special2,
                           steps: [
                             %Spark.Test.Atom{name: :bar}
                           ]
                         }
                       ]
                     }
                   ]
                 },
                 %Spark.Test.Step{
                   name: :not_special,
                   steps: [
                     %Spark.Test.Step{
                       name: :special2,
                       steps: [
                         %Spark.Test.Atom{name: :bar}
                       ]
                     }
                   ]
                 }
               ]
             }
           ] = Info.steps(DeeplyNested)
  end
end
