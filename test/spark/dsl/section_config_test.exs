# SPDX-FileCopyrightText: 2026 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Dsl.SectionConfigTest do
  use ExUnit.Case, async: true

  alias Spark.Dsl.SectionConfig
  alias Spark.Dsl.Transformer

  defmodule Contact do
    @moduledoc false
    use Spark.Test.Contact

    presets do
      preset(:test_preset)
    end

    contact do
      module(Some.Module)
    end
  end

  test "compiled DSL state stores every section as a SectionConfig" do
    sections =
      Contact.spark_dsl_config()
      |> Enum.filter(fn {path, _} -> is_list(path) end)

    assert sections != []
    assert Enum.all?(sections, fn {_path, config} -> match?(%SectionConfig{}, config) end)
  end

  test "transformer functions create complete configs for new section paths" do
    dsl_state =
      %{}
      |> Transformer.add_entity([:added], :entity)
      |> Transformer.remove_entity([:removed], fn _ -> true end)
      |> Transformer.set_option([:optioned], :key, :value)

    assert dsl_state[[:added]] == %SectionConfig{entities: [:entity]}
    assert dsl_state[[:removed]] == %SectionConfig{}
    assert dsl_state[[:optioned]] == %SectionConfig{opts: [key: :value]}
  end

  describe "Access" do
    test "reads fields and returns nil for unknown keys" do
      config = %SectionConfig{opts: [key: :value]}

      assert config[:opts] == [key: :value]
      assert config[:entities] == []
      assert config[:unknown] == nil
      assert get_in(%{[:section] => config}, [[:section], :opts, :key]) == :value
    end

    test "updates fields" do
      config = put_in(%SectionConfig{}[:opts], key: :value)

      assert %SectionConfig{opts: [key: :value]} = config
    end

    test "raises when updating an unknown key" do
      assert_raise KeyError, fn -> put_in(%SectionConfig{}[:unknown], :value) end
    end

    test "pop resets the field to its default" do
      assert {[:entity], %SectionConfig{entities: []}} =
               pop_in(%SectionConfig{entities: [:entity]}[:entities])
    end
  end
end
