# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.DocsTest do
  use ExUnit.Case

  describe "redirects_for/2" do
    test "generates redirects for entities in sections" do
      redirects = Spark.Docs.redirects_for([Spark.Test.Contact.Dsl])

      # Check that entity modules are mapped to the correct DSL doc paths
      assert redirects["Spark.Test.Contact.Dsl.Presets.Preset"] ==
               "dsl-spark-test-contact#presets-preset"

      assert redirects["Spark.Test.Contact.Dsl.Presets.PresetWithOptional"] ==
               "dsl-spark-test-contact#presets-preset_with_optional"

      assert redirects["Spark.Test.Contact.Dsl.Presets.PresetWithFnArg"] ==
               "dsl-spark-test-contact#presets-preset_with_fn_arg"
    end

    test "generates redirects for nested entities" do
      redirects = Spark.Docs.redirects_for([Spark.Test.Contact.Dsl])

      # The singleton entity is nested under preset
      assert redirects["Spark.Test.Contact.Dsl.Presets.Preset.Singleton"] ==
               "dsl-spark-test-contact#presets-preset-singleton"
    end

    test "merges with existing redirects" do
      existing = %{"existing-page" => "new-page"}
      redirects = Spark.Docs.redirects_for([Spark.Test.Contact.Dsl], existing)

      # Should contain existing redirect
      assert redirects["existing-page"] == "new-page"

      # Should also contain the generated redirects
      assert redirects["Spark.Test.Contact.Dsl.Presets.Preset"] ==
               "dsl-spark-test-contact#presets-preset"
    end

    test "handles multiple DSL extensions" do
      redirects = Spark.Docs.redirects_for([Spark.Test.Contact.Dsl, Spark.Test.Recursive.Dsl])

      # Should have redirects from Contact.Dsl
      assert redirects["Spark.Test.Contact.Dsl.Presets.Preset"] ==
               "dsl-spark-test-contact#presets-preset"

      # Should have redirects from Recursive.Dsl
      assert redirects["Spark.Test.Recursive.Dsl.Steps.Step"] ==
               "dsl-spark-test-recursive#steps-step"
    end

    test "handles DSL patches" do
      redirects = Spark.Docs.redirects_for([Spark.Test.ContactPatcher])

      # The ContactPatcher adds special_preset to presets section
      assert redirects["Spark.Test.ContactPatcher.Presets.SpecialPreset"] ==
               "dsl-spark-test-contactpatcher#presets-special_preset"
    end
  end

  describe "search_data_for/1" do
    test "generates search data for sections" do
      search_data = Spark.Docs.search_data_for(Spark.Test.Contact.Dsl)

      # Find the presets section entry
      presets_entry = Enum.find(search_data, &(&1.anchor == "presets"))
      assert presets_entry
      assert presets_entry.title == "presets"
      assert presets_entry.type == "DSL"
    end

    test "generates search data for entities" do
      search_data = Spark.Docs.search_data_for(Spark.Test.Contact.Dsl)

      # Find the preset entity entry
      preset_entry = Enum.find(search_data, &(&1.anchor == "presets-preset"))
      assert preset_entry
      assert preset_entry.title == "presets.preset"
      assert preset_entry.type == "DSL"
    end

    test "generates search data for schema options" do
      search_data = Spark.Docs.search_data_for(Spark.Test.Contact.Dsl)

      # Find a schema option entry (first_name from personal_details)
      first_name_entry = Enum.find(search_data, &(&1.anchor == "personal_details-first_name"))
      assert first_name_entry
      assert first_name_entry.title == "personal_details.first_name"
      assert first_name_entry.type == "DSL"
    end
  end
end
