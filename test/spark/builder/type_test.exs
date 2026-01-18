# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.TypeTest do
  use ExUnit.Case, async: true

  alias Spark.Builder.Type

  describe "basic types" do
    test "returns correct atoms for basic types" do
      assert Type.any() == :any
      assert Type.atom() == :atom
      assert Type.string() == :string
      assert Type.boolean() == :boolean
      assert Type.integer() == :integer
      assert Type.non_neg_integer() == :non_neg_integer
      assert Type.pos_integer() == :pos_integer
      assert Type.float() == :float
      assert Type.number() == :number
      assert Type.timeout() == :timeout
      assert Type.pid() == :pid
      assert Type.reference() == :reference
      assert Type.module() == :module
      assert Type.mfa() == :mfa
      assert Type.mod_arg() == :mod_arg
      assert Type.regex() == :regex
      assert Type.regex_as_mfa() == :regex_as_mfa
      assert Type.literal() == :literal
      assert Type.quoted() == :quoted
      assert Type.struct() == :struct
      assert Type.fun() == :fun
      assert Type.keyword_list() == :keyword_list
      assert Type.non_empty_keyword_list() == :non_empty_keyword_list
      assert Type.map() == :map
    end
  end

  describe "parameterized types" do
    test "fun/1 with arity" do
      assert Type.fun(0) == {:fun, 0}
      assert Type.fun(1) == {:fun, 1}
      assert Type.fun(2) == {:fun, 2}
    end

    test "fun/2 with arg types and return type" do
      assert Type.fun([:atom, :string], :boolean) == {:fun, [:atom, :string], :boolean}
    end

    test "list/1" do
      assert Type.list(:atom) == {:list, :atom}
      assert Type.list(:string) == {:list, :string}
      assert Type.list({:tuple, [:atom, :any]}) == {:list, {:tuple, [:atom, :any]}}
    end

    test "wrap_list/1" do
      assert Type.wrap_list(:atom) == {:wrap_list, :atom}
    end

    test "tuple/1" do
      assert Type.tuple([:atom, :string]) == {:tuple, [:atom, :string]}
      assert Type.tuple([:atom, :integer, :boolean]) == {:tuple, [:atom, :integer, :boolean]}
    end

    test "map/2 with key and value types" do
      assert Type.map(:atom, :any) == {:map, :atom, :any}
      assert Type.map(:string, :integer) == {:map, :string, :integer}
    end

    test "struct/1" do
      assert Type.struct(MyStruct) == {:struct, MyStruct}
    end

    test "literal/1" do
      assert Type.literal(:specific_value) == {:literal, :specific_value}
      assert Type.literal("string") == {:literal, "string"}
    end

    test "keyword_list/1 with schema" do
      schema = [host: [type: :string], port: [type: :integer]]
      assert Type.keyword_list(schema) == {:keyword_list, schema}
    end

    test "non_empty_keyword_list/1 with schema" do
      schema = [name: [type: :atom, required: true]]
      assert Type.non_empty_keyword_list(schema) == {:non_empty_keyword_list, schema}
    end

    test "map/1 with schema" do
      schema = [name: [type: :string]]
      assert Type.map(schema) == {:map, schema}
    end
  end

  describe "choice types" do
    test "in_choices/1" do
      assert Type.in_choices([:pending, :active]) == {:in, [:pending, :active]}
      assert Type.in_choices(1..10) == {:in, 1..10}
    end

    test "one_of/1" do
      assert Type.one_of([:read, :write]) == {:one_of, [:read, :write]}
    end

    test "tagged_tuple/2" do
      assert Type.tagged_tuple(:ok, :any) == {:tagged_tuple, :ok, :any}
      assert Type.tagged_tuple(:error, :string) == {:tagged_tuple, :error, :string}
    end
  end

  describe "combinators" do
    test "or_types/1" do
      assert Type.or_types([:atom, :string]) == {:or, [:atom, :string]}
      assert Type.or_types([{:list, :atom}, :atom]) == {:or, [{:list, :atom}, :atom]}
    end

    test "and_types/1" do
      assert Type.and_types([:atom, {:in, [:foo, :bar]}]) == {:and, [:atom, {:in, [:foo, :bar]}]}
    end
  end

  describe "custom validation" do
    test "custom/2 with module and function" do
      assert Type.custom(MyValidator, :validate) == {:custom, MyValidator, :validate, []}
    end

    test "custom/3 with args" do
      assert Type.custom(MyValidator, :validate, [:strict]) ==
               {:custom, MyValidator, :validate, [:strict]}
    end

    test "mfa_or_fun/1" do
      assert Type.mfa_or_fun(1) == {:mfa_or_fun, 1}
      assert Type.mfa_or_fun(2) == {:mfa_or_fun, 2}
    end
  end

  describe "spark-specific types" do
    test "spark/1" do
      assert Type.spark(Ash.Resource) == {:spark, Ash.Resource}
    end

    test "behaviour/1" do
      assert Type.behaviour(GenServer) == {:behaviour, GenServer}
    end

    test "protocol/1" do
      assert Type.protocol(Enumerable) == {:protocol, Enumerable}
    end

    test "impl/1" do
      assert Type.impl(String.Chars) == {:impl, String.Chars}
    end

    test "spark_behaviour/1" do
      assert Type.spark_behaviour(MyBehaviour) == {:spark_behaviour, MyBehaviour}
    end

    test "spark_behaviour/2 with builtin" do
      assert Type.spark_behaviour(MyBehaviour, MyBuiltins) ==
               {:spark_behaviour, MyBehaviour, MyBuiltins}
    end

    test "spark_function_behaviour/2" do
      assert Type.spark_function_behaviour(MyBehaviour, {MyBehaviour.Function, 1}) ==
               {:spark_function_behaviour, MyBehaviour, {MyBehaviour.Function, 1}}
    end

    test "spark_function_behaviour/3 with builtin" do
      assert Type.spark_function_behaviour(MyBehaviour, MyBuiltins, {MyBehaviour.Function, 1}) ==
               {:spark_function_behaviour, MyBehaviour, MyBuiltins, {MyBehaviour.Function, 1}}
    end

    test "spark_type/2" do
      assert Type.spark_type(MyType, :builtins) == {:spark_type, MyType, :builtins}
    end

    test "spark_type/3 with templates" do
      assert Type.spark_type(MyType, :builtins, ["t1", "t2"]) ==
               {:spark_type, MyType, :builtins, ["t1", "t2"]}
    end
  end
end
