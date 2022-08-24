defmodule Spark.Test.FormatterTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:spark, :formatter)
    end)
  end

  defp config_contact(config, mod \\ "Spark.Test.Contact") do
    Application.put_env(:spark, :formatter, [{mod, config}])
  end

  test "it reorders sections properly" do
    config_contact(section_order: [:address, :personal_details])

    assert Spark.Formatter.format(
             """
             defmodule IncredibleHulk do
               use Spark.Test.Contact

               personal_details do
                 first_name("Incredible")
                 last_name("Hulk")
               end

               address do
                 street("Avenger Lane")
               end
             end
             """,
             []
           ) == """
           defmodule IncredibleHulk do
             use Spark.Test.Contact

             address do
               street("Avenger Lane")
             end

             personal_details do
               first_name("Incredible")
               last_name("Hulk")
             end
           end
           """
  end

  test "it reorders sections properly when using a base resource" do
    config_contact(
      [type: Spark.Test.Contact, section_order: [:address, :personal_details]],
      "Base"
    )

    assert Spark.Formatter.format(
             """
             defmodule IncredibleHulk do
               use Base

               personal_details do
                 first_name("Incredible")
                 last_name("Hulk")
               end

               address do
                 street("Avenger Lane")
               end
             end
             """,
             []
           ) == """
           defmodule IncredibleHulk do
             use Base

             address do
               street("Avenger Lane")
             end

             personal_details do
               first_name("Incredible")
               last_name("Hulk")
             end
           end
           """
  end
end
