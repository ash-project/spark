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
end
