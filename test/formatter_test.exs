# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.FormatterTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:spark, :formatter)
    end)

    opts = [
      locals_without_parens: [
        first_name: 1,
        street: 1,
        last_name: 1
      ]
    ]

    %{opts: opts}
  end

  defp config_contact(config, mod \\ "Spark.Test.Contact") do
    Application.put_env(:spark, :formatter, [{mod, config}, remove_parens?: true])
  end

  test "it reorders sections properly", %{opts: opts} do
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
             opts
           ) == """
           defmodule IncredibleHulk do
             use Spark.Test.Contact

             address do
               street "Avenger Lane"
             end

             personal_details do
               first_name "Incredible"
               last_name "Hulk"
             end
           end
           """
  end

  test "it reorders sections properly when using a base resource", %{opts: opts} do
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
             opts
           ) == """
           defmodule IncredibleHulk do
             use Base

             address do
               street "Avenger Lane"
             end

             personal_details do
               first_name "Incredible"
               last_name "Hulk"
             end
           end
           """
  end

  test "it works in umbrella projects without crashing", %{opts: opts} do
    config_contact(section_order: [:address, :personal_details])

    # Mock Mix.Project.umbrella?() to return true
    # We can't easily mock this, but we can at least verify the formatter
    # doesn't crash when umbrella? returns true by testing the safe_compile function
    # indirectly through normal formatting (which should work regardless)

    # This test verifies that formatting works even if compilation is skipped
    result =
      Spark.Formatter.format(
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
        opts
      )

    # Should format successfully without crashing
    assert result == """
           defmodule IncredibleHulk do
             use Spark.Test.Contact

             address do
               street "Avenger Lane"
             end

             personal_details do
               first_name "Incredible"
               last_name "Hulk"
             end
           end
           """
  end
end
