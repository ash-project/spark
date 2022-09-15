defmodule Spark.DslTest do
  use ExUnit.Case

  test "defining an instance of the DSL works" do
    defmodule HanSolo do
      use Spark.Test.Contact

      personal_details do
        first_name("Han")
        last_name("Solo")
      end
    end
  end

  describe "docs_test" do
    test "adds docs" do
      {:docs_v1, _, _, _, %{"en" => docs}, _, _} = Code.fetch_docs(TedDansen)
      assert docs =~ "first_name: Ted"
      assert docs =~ "last_name: Dansen"
    end
  end
end
