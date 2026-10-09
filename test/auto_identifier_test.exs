# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AutoIdentifierTest do
  use ExUnit.Case

  defmodule Item do
    defstruct [:name, :__identifier__, :__spark_metadata__]
  end

  defmodule AddItem do
    use Spark.Dsl.Transformer

    def transform(dsl_state) do
      item =
        Spark.Dsl.Transformer.build_entity!(AutoIdentifierTest.Dsl, [:items], :item, name: :added)

      {:ok, Spark.Dsl.Transformer.add_entity(dsl_state, [:items], item, type: :append)}
    end
  end

  defmodule Dsl do
    @item %Spark.Dsl.Entity{
      name: :item,
      target: Item,
      args: [:name],
      identifier: {:auto, :unique_integer},
      schema: [name: [type: :atom]]
    }

    @items %Spark.Dsl.Section{name: :items, entities: [@item]}

    use Spark.Dsl.Extension, sections: [@items], transformers: [AddItem]
    use Spark.Dsl, default_extensions: [extensions: Dsl]
  end

  @source """
  defmodule AutoIdentifierTest.Compiled do
    use AutoIdentifierTest.Dsl

    items do
      item :first
      item :second
    end
  end
  """

  defp compile_and_read do
    # Each compilation in its own process, like the parallel compiler, with
    # unique integers drawn in between so that a counter leaking from the VM
    # would show.
    Task.async(fn ->
      Code.compiler_options(ignore_module_conflict: true)
      Code.compile_string(@source)
      Enum.each(1..5, fn _ -> System.unique_integer() end)

      identifiers =
        AutoIdentifierTest.Compiled
        |> Spark.Dsl.Extension.get_entities([:items])
        |> Enum.map(&{&1.name, &1.__identifier__})

      :code.purge(AutoIdentifierTest.Compiled)
      :code.delete(AutoIdentifierTest.Compiled)
      identifiers
    end)
    |> Task.await()
  end

  test "entities built while a module compiles get the same identifiers every time" do
    first = compile_and_read()
    second = compile_and_read()

    assert first == second

    assert first == [
             first: {AutoIdentifierTest.Compiled, 0},
             second: {AutoIdentifierTest.Compiled, 1},
             added: {AutoIdentifierTest.Compiled, 2}
           ]
  end

  test "entities built outside a module's compilation keep a unique integer" do
    {:ok, one} = Spark.Dsl.Transformer.build_entity(Dsl, [:items], :item, name: :one)
    {:ok, two} = Spark.Dsl.Transformer.build_entity(Dsl, [:items], :item, name: :one)

    assert is_integer(one.__identifier__)
    assert one.__identifier__ != two.__identifier__
  end
end
