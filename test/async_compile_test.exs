# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.AsyncCompileTest do
  use ExUnit.Case, async: true

  alias Spark.Dsl.Transformer

  defmodule Trigger do
    defstruct [:name, :__identifier__, :__spark_metadata__]
  end

  defmodule DefineTriggerModules do
    @moduledoc false
    use Spark.Dsl.Transformer

    alias Spark.Dsl.Transformer

    # Queues one module per trigger, closing over the whole dsl as AshOban's
    # DefineSchedulers does
    def transform(dsl) do
      module = Transformer.get_persisted(dsl, :module)

      dsl
      |> Transformer.get_entities([:triggers])
      |> Enum.reduce(dsl, fn trigger, dsl ->
        Transformer.async_compile(dsl, fn ->
          name = trigger.name
          triggers = length(Transformer.get_entities(dsl, [:triggers]))

          Module.create(
            Module.concat(module, Macro.camelize(to_string(name))),
            quote do
              def name, do: unquote(name)
              def triggers, do: unquote(triggers)
            end,
            Macro.Env.location(__ENV__)
          )
        end)
      end)
      |> then(&{:ok, &1})
    end
  end

  defmodule Extension do
    @moduledoc false
    @trigger %Spark.Dsl.Entity{
      name: :trigger,
      target: Trigger,
      args: [:name],
      schema: [name: [type: :atom, required: true]]
    }

    use Spark.Dsl.Extension,
      sections: [%Spark.Dsl.Section{name: :triggers, entities: [@trigger]}],
      transformers: [DefineTriggerModules]
  end

  defmodule Dsl do
    @moduledoc false
    use Spark.Dsl, default_extensions: [extensions: [Extension]]
  end

  defmodule WithTriggers do
    @moduledoc false
    use Dsl

    triggers do
      trigger(:first)
      trigger(:second)
      trigger(:third)
    end
  end

  test "modules queued with async_compile are compiled with the module" do
    assert WithTriggers.First.name() == :first
    assert WithTriggers.Third.triggers() == 3
  end

  test "a fun queued with async_compile doesn't carry the funs queued before it" do
    dsl = %{persist: %{module: __MODULE__.Queued}}

    dsl =
      Enum.reduce(1..16, dsl, fn i, dsl ->
        Transformer.async_compile(dsl, fn -> {i, dsl} end)
      end)

    try do
      # Each fun captures the dsl it was queued on. If the dsl holds the earlier funs,
      # the size of a copy (which loses sharing, as spawning a task does) doubles with
      # each one.
      assert :erts_debug.flat_size(dsl) < 1_000
    after
      Spark.Dsl.Extension.await_persisted_compile_funs(dsl)
    end
  end
end
