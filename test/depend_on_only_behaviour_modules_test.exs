# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.DependOnOnlyBehaviourModulesTest do
  use ExUnit.Case, async: false

  defmodule Check do
    @moduledoc false
    defstruct [:check, :where, :__spark_metadata__]
  end

  defmodule Extension do
    @moduledoc false

    @check %Spark.Dsl.Entity{
      name: :check,
      target: Spark.DependOnOnlyBehaviourModulesTest.Check,
      args: [:check],
      depend_on_only_behaviour_modules: [:check, :where],
      schema: [
        check: [type: :any, required: true],
        where: [type: {:list, :any}, default: []]
      ]
    }

    @checks %Spark.Dsl.Section{name: :checks, entities: [@check]}

    use Spark.Dsl.Extension, sections: [@checks]
  end

  defmodule Dsl do
    @moduledoc false
    use Spark.Dsl,
      default_extensions: [extensions: Spark.DependOnOnlyBehaviourModulesTest.Extension]
  end

  defmodule Builders do
    @moduledoc false
    def build(source), do: {Spark.DependOnOnlyBehaviourModulesTest.BuiltCheck, source: source}
  end

  defmodule Tracer do
    @moduledoc false
    def trace({:on_module, _, _}, env) do
      {compile, exports, runtime, _} = Kernel.LexicalTracker.references(env.lexical_tracker)
      send(:persistent_term.get(__MODULE__), {:references, env.module, compile, exports, runtime})
      :ok
    end

    def trace(_event, _env), do: :ok
  end

  test "only the behaviour module of each value becomes a compile time dependency" do
    :persistent_term.put(Tracer, self())
    tracers = Code.get_compiler_option(:tracers)
    Code.put_compiler_option(:tracers, [Tracer | tracers])

    try do
      Code.compile_string("""
      defmodule Spark.DependOnOnlyBehaviourModulesTest.Example do
        use Spark.DependOnOnlyBehaviourModulesTest.Dsl

        alias Spark.DependOnOnlyBehaviourModulesTest.{Builders, Other}

        checks do
          check {Spark.DependOnOnlyBehaviourModulesTest.TupleCheck, source: Other.Tuple}

          check Spark.DependOnOnlyBehaviourModulesTest.AtomCheck do
            where [{Spark.DependOnOnlyBehaviourModulesTest.WhereCheck, type: Other.Where}]
          end

          check Builders.build(Other.Call)
        end
      end
      """)
    after
      Code.put_compiler_option(:tracers, tracers)
    end

    module = Spark.DependOnOnlyBehaviourModulesTest.Example
    assert_received {:references, ^module, compile, exports, runtime}

    for behaviour <- [
          Spark.DependOnOnlyBehaviourModulesTest.TupleCheck,
          Spark.DependOnOnlyBehaviourModulesTest.AtomCheck,
          Spark.DependOnOnlyBehaviourModulesTest.WhereCheck,
          Spark.DependOnOnlyBehaviourModulesTest.Builders
        ] do
      assert behaviour in compile
    end

    for other <- [
          Spark.DependOnOnlyBehaviourModulesTest.Other.Tuple,
          Spark.DependOnOnlyBehaviourModulesTest.Other.Where,
          Spark.DependOnOnlyBehaviourModulesTest.Other.Call
        ] do
      refute other in compile
      refute other in exports
      refute other in runtime
    end

    assert [tuple, atom, call] = Spark.Dsl.Extension.get_entities(module, [:checks])

    assert tuple.check ==
             {Spark.DependOnOnlyBehaviourModulesTest.TupleCheck,
              source: Spark.DependOnOnlyBehaviourModulesTest.Other.Tuple}

    assert atom.check == Spark.DependOnOnlyBehaviourModulesTest.AtomCheck

    assert atom.where == [
             {Spark.DependOnOnlyBehaviourModulesTest.WhereCheck,
              type: Spark.DependOnOnlyBehaviourModulesTest.Other.Where}
           ]

    assert call.check ==
             {Spark.DependOnOnlyBehaviourModulesTest.BuiltCheck,
              source: Spark.DependOnOnlyBehaviourModulesTest.Other.Call}
  end
end
