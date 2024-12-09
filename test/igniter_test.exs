defmodule Spark.IgniterTest do
  use ExUnit.Case

  import Igniter.Test

  test "options are found in DSLs" do
    assert {_igniter, {:ok, Bar.Baz}} =
             test_project()
             |> Igniter.Code.Project.create_module(TedDansen, """
               use Spark.Test.Contact

               contact do
                 module(Bar.Baz)
               end
             """)
             |> Spark.Igniter.get_option(TedDansen, [:contact, :module])
  end

  test "options are found in fragments" do
    assert {_igniter, {:ok, "foobar"}} =
             test_project()
             |> Igniter.Code.Project.create_module(TedDansenFragment, """
             @moduledoc false
             use Spark.Dsl.Fragment, of: Spark.Test.Contact

             address do
               street("foobar")
             end
             """)
             |> Igniter.Code.Project.create_module(TedDansen, """
               use Spark.Test.Contact, fragments: [TedDansenFragment]

               contact do
                 module(Bar.Baz)
               end
             """)
             |> Spark.Igniter.get_option(TedDansen, [:address, :street])
  end
end
