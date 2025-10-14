# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.TopLevelTest do
  use ExUnit.Case

  alias Spark.Test.TopLevel.Info

  test "top level DSL entities are available" do
    defmodule Simple do
      use Spark.Test.TopLevel

      foo(10)

      step :foo do
        step(:bar)
      end
    end

    assert [%Spark.Test.Step{name: :foo, steps: [%Spark.Test.Step{}]}] = Info.steps(Simple)
    assert {:ok, 10} = Info.steps_foo(Simple)
  end

  test "nested DSL sections are available" do
    defmodule Nested do
      use Spark.Test.TopLevel

      nested_section do
        bar(20)
      end

      foo(10)

      step :foo do
        step(:bar)
      end
    end

    assert [%Spark.Test.Step{name: :foo, steps: [%Spark.Test.Step{}]}] = Info.steps(Nested)
    assert {:ok, 10} = Info.steps_foo(Nested)
    assert {:ok, 20} = Info.steps_nested_section_bar(Nested)
  end
end
