defmodule SparkTest do
  use ExUnit.Case
  doctest Spark

  test "greets the world" do
    assert Spark.hello() == :world
  end
end
