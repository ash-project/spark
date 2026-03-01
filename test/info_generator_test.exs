# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.InfoGeneratorTest do
  use ExUnit.Case

  alias MyExtension.Info

  defmodule Resource do
    use MyExtension.Dsl
  end

  describe "map default values" do
    test "returns the default map when option is not set" do
      assert {:ok, %{}} = Info.my_section_map_option(Resource)
    end

    test "bang variant returns the default map when option is not set" do
      assert %{} = Info.my_section_map_option!(Resource)
    end
  end
end
