# SPDX-FileCopyrightText: 2026 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule PersisterSortTest do
  use ExUnit.Case

  defmodule PersisterA do
    use Spark.Dsl.Transformer

    def transform(dsl) do
      order = Spark.Dsl.Transformer.get_persisted(dsl, :persister_order, [])
      {:ok, Spark.Dsl.Transformer.persist(dsl, :persister_order, order ++ [:a])}
    end
  end

  defmodule PersisterB do
    use Spark.Dsl.Transformer

    def before?(PersisterSortTest.PersisterA), do: true
    def before?(_), do: false

    def transform(dsl) do
      order = Spark.Dsl.Transformer.get_persisted(dsl, :persister_order, [])
      {:ok, Spark.Dsl.Transformer.persist(dsl, :persister_order, order ++ [:b])}
    end
  end

  defmodule PersisterC do
    use Spark.Dsl.Transformer

    def after?(PersisterSortTest.PersisterA), do: true
    def after?(_), do: false

    def transform(dsl) do
      order = Spark.Dsl.Transformer.get_persisted(dsl, :persister_order, [])
      {:ok, Spark.Dsl.Transformer.persist(dsl, :persister_order, order ++ [:c])}
    end
  end

  defmodule Extension do
    @section %Spark.Dsl.Section{
      name: :test_section,
      schema: []
    }

    use Spark.Dsl.Extension,
      sections: [@section],
      # Listed in reverse order to prove sorting works
      persisters: [PersisterC, PersisterA, PersisterB]
  end

  defmodule TestDsl do
    use Spark.Dsl, default_extensions: [extensions: PersisterSortTest.Extension]
  end

  defmodule TestResource do
    use TestDsl
  end

  test "persisters are sorted based on before/after callbacks" do
    assert Spark.Dsl.Extension.get_persisted(TestResource, :persister_order) == [:b, :a, :c]
  end
end
