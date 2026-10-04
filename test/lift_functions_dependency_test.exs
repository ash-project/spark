# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.LiftFunctionsDependencyTest do
  use ExUnit.Case, async: false

  defmodule Target do
    @moduledoc false
    def callback(_), do: "callback"
    def handler(_), do: "handler"
    def one(_), do: :one
    def two(_), do: :two
  end

  defmodule Tracer do
    @moduledoc false
    def trace({:on_module, _, _}, env) do
      references = Kernel.LexicalTracker.references(env.lexical_tracker)
      compile = elem(references, 0)
      runtime = elem(references, 2)
      send(:persistent_term.get(__MODULE__), {:references, env.module, compile, runtime})
      :ok
    end

    def trace(_event, _env), do: :ok
  end

  test "remote captures in option values create runtime, not compile time, dependencies" do
    :persistent_term.put(Tracer, self())
    tracers = Code.get_compiler_option(:tracers)
    Code.put_compiler_option(:tracers, [Tracer | tracers])

    try do
      Code.compile_string("""
      defmodule Spark.LiftFunctionsDependencyTest.Example do
        use MyExtension.Dsl

        alias Spark.LiftFunctionsDependencyTest.Target

        my_section do
          callback &Target.callback/1
          handler &Spark.LiftFunctionsDependencyTest.Target.handler/1
          map_option %{fun: &Target.one/1}
          any_option [{:a, &Target.one/1}, {&Target.two/1, :b}]
        end
      end
      """)
    after
      Code.put_compiler_option(:tracers, tracers)
    end

    module = Spark.LiftFunctionsDependencyTest.Example
    assert_received {:references, ^module, compile, runtime}

    refute Target in compile
    assert Target in runtime

    assert Spark.Dsl.Extension.get_opt(module, [:my_section], :callback) == (&Target.callback/1)
    assert Spark.Dsl.Extension.get_opt(module, [:my_section], :handler) == (&Target.handler/1)

    assert Spark.Dsl.Extension.get_opt(module, [:my_section], :map_option) == %{
             fun: &Target.one/1
           }

    assert Spark.Dsl.Extension.get_opt(module, [:my_section], :any_option) == [
             {:a, &Target.one/1},
             {&Target.two/1, :b}
           ]
  end
end
