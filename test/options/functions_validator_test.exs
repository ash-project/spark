defmodule Spark.Options.FunctionsValidatorTest do
  use ExUnit.Case
  require Spark.Options.Validator

  defmodule MySchema do
    @schema [
      foo: [
        type: :fun
      ],
      bar: [
        type: {:fun, 2}
      ],
      two_tuple: [
        type: {:tuple, [:any, {:fun, 1}]}
      ],
      list: [
        type: {:list, {:fun, 1}}
      ]
    ]

    def anything(value), do: {:ok, value}

    use Spark.Options.Validator, schema: @schema, define_deprecated_access?: true
  end

  def func(_), do: 42
  def func(_, _), do: 99

  describe "function types" do
    test "accept anonymous function at top level" do
      opts = MySchema.to_options(MySchema.validate!(foo: fn f -> f end))
      assert is_function(opts[:foo], 1)
      assert opts[:foo].(opts[:foo]) == opts[:foo]
    end

    test "accept anonymous function with arity at top level" do
      opts = MySchema.to_options(MySchema.validate!(bar: fn a, b -> {a, b} end))
      assert is_function(opts[:bar], 2)
      assert opts[:bar].(42, :ok) == {42, :ok}
    end

    test "accept function in current module at top level" do
      opts = MySchema.to_options(MySchema.validate!(foo: &func/1))
      assert is_function(opts[:foo], 1)
      assert opts[:foo].(:ok) == 42
    end

    test "accept function in another module at top level" do
      opts = MySchema.to_options(MySchema.validate!(foo: &Enum.to_list/1))
      assert is_function(opts[:foo], 1)
      assert opts[:foo].(%{x: 42}) == [x: 42]
    end

    test "check function arity at top level" do
      assert_raise(Spark.Options.ValidationError, fn ->
        MySchema.to_options(MySchema.validate!(bar: fn a -> a end))
      end)

      assert_raise(Spark.Options.ValidationError, fn ->
        MySchema.to_options(MySchema.validate!(bar: &func/1))
      end)

      assert_raise(Spark.Options.ValidationError, fn ->
        MySchema.to_options(MySchema.validate!(bar: &Enum.to_list/1))
      end)
    end

    test "accept anonymous function in a tuple" do
      opts = MySchema.to_options(MySchema.validate!(two_tuple: {:anything, fn f -> f end}))
      {_, fun} = opts[:two_tuple]
      assert is_function(fun, 1)
      assert fun.(opts[:two_tuple]) == opts[:two_tuple]
    end

    test "accept anonymous function with arity in a tuple" do
      opts =
        MySchema.to_options(MySchema.validate!(two_tuple: {:anything, fn a -> {a, 99} end}))

      {_, fun} = opts[:two_tuple]
      assert is_function(fun, 1)
      assert fun.(42) == {42, 99}
    end

    test "accept function in current module in a tuple" do
      opts = MySchema.to_options(MySchema.validate!(two_tuple: {:anything, &func/1}))
      {_, fun} = opts[:two_tuple]
      assert is_function(fun, 1)
      assert fun.(:ok) == 42
    end

    test "accept function in another module in a tuple" do
      opts = MySchema.to_options(MySchema.validate!(two_tuple: {:anything, &Enum.to_list/1}))
      {_, fun} = opts[:two_tuple]
      assert is_function(fun, 1)
      assert fun.(%{x: 42}) == [x: 42]
    end

    test "check function arity in a tuple" do
      assert_raise(Spark.Options.ValidationError, ~r/expected function of arity 1/, fn ->
        MySchema.to_options(MySchema.validate!(two_tuple: {:anything, fn a, b -> {a, b} end}))
      end)

      assert_raise(Spark.Options.ValidationError, ~r/expected function of arity 1/, fn ->
        MySchema.to_options(MySchema.validate!(two_tuple: {:anything, &func/2}))
      end)

      assert_raise(Spark.Options.ValidationError, ~r/expected function of arity 1/, fn ->
        MySchema.to_options(MySchema.validate!(two_tuple: {:anything, &Enum.map/2}))
      end)
    end

    test "accept anonymous function in a list" do
      opts = MySchema.to_options(MySchema.validate!(list: [fn f -> f end]))
      [fun] = opts[:list]
      assert is_function(fun, 1)
      assert fun.(opts[:list]) == opts[:list]
    end

    test "accept anonymous function with arity in a list" do
      opts =
        MySchema.to_options(MySchema.validate!(list: [fn a -> {a, 99} end]))

      [fun] = opts[:list]
      assert is_function(fun, 1)
      assert fun.(42) == {42, 99}
    end

    test "accept function in current module in a list" do
      opts = MySchema.to_options(MySchema.validate!(list: [&func/1]))
      [fun] = opts[:list]
      assert is_function(fun, 1)
      assert fun.(:ok) == 42
    end

    test "accept function in another module in a list" do
      opts = MySchema.to_options(MySchema.validate!(list: [&Enum.to_list/1]))
      [fun] = opts[:list]
      assert is_function(fun, 1)
      assert fun.(%{x: 42}) == [x: 42]
    end

    test "check function arity in a list" do
      assert_raise(Spark.Options.ValidationError, ~r/expected function of arity 1/, fn ->
        MySchema.to_options(MySchema.validate!(list: [fn a, b -> {a, b} end]))
      end)

      assert_raise(Spark.Options.ValidationError, ~r/expected function of arity 1/, fn ->
        MySchema.to_options(MySchema.validate!(list: [&func/2]))
      end)

      assert_raise(Spark.Options.ValidationError, ~r/expected function of arity 1/, fn ->
        MySchema.to_options(MySchema.validate!(list: [&Enum.map/2]))
      end)
    end
  end
end
