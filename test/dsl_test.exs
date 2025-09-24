defmodule Spark.DslTest do
  use ExUnit.Case

  import Spark.CodeHelpers

  test "defining an instance of the DSL works" do
    defmodule HanSolo do
      @moduledoc false
      use Spark.Test.Contact

      personal_details do
        first_name("Han")
        last_name("Solo")
      end
    end
  end

  test "no depend modules still allows for aliases" do
    defmodule The.Contacter do
      def something(_), do: :ok
    end

    defmodule CrashBandicoot do
      use Spark.Test.Contact

      alias The.Contacter

      contact do
        module(Contacter)
      end
    end

    assert(Spark.Test.Contact.Info.module(CrashBandicoot) == The.Contacter)
  end

  describe "module conflicts" do
    test "options don't conflict with outermost sections" do
      defmodule MoffGideon do
        @moduledoc false
        use Spark.Test.Contact

        personal_details do
          first_name("Moff")
          last_name("Gideon")
          contact("foo")
        end
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

  describe "anonymous functions in DSL" do
    test "creates a function and passes it to the default" do
      defmodule ObiWan do
        @moduledoc false
        use Spark.Test.Contact

        contact do
          contacter(fn message when not is_nil(message) ->
            "Help me Obi-Wan Kenobi: #{message}"
          end)
        end
      end

      assert {Spark.Test.Contact.Contacter.Function, opts} =
               Spark.Test.Contact.Info.contacter(ObiWan)

      assert opts[:fun].("you're my only hope.") ==
               "Help me Obi-Wan Kenobi: you're my only hope."
    end

    test "supports multiple function clauses" do
      defmodule Prequel do
        @moduledoc false
        use Spark.Test.Contact

        contact do
          contacter(fn
            "Hello there" ->
              "General Kenobi"

            "A surprise to be sure" ->
              "But a welcome one"

            "This is outrageous" ->
              "It's unfair"
          end)
        end
      end

      assert {Spark.Test.Contact.Contacter.Function, opts} =
               Spark.Test.Contact.Info.contacter(Prequel)

      assert opts[:fun].("Hello there") == "General Kenobi"
      assert opts[:fun].("A surprise to be sure") == "But a welcome one"
      assert opts[:fun].("This is outrageous") == "It's unfair"
    end

    test "entities support functions in option setters" do
      defmodule PaulMcCartney do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset :help do
            default_message("help")

            contacter(fn message ->
              "#{message}: I need some body"
            end)
          end
        end
      end

      assert [preset] = Spark.Test.Contact.Info.presets(PaulMcCartney)
      assert preset.default_message == "help"

      assert {_, [fun: fun]} = preset.contacter

      assert fun.("Help") ==
               "Help: I need some body"
    end

    test "entities can functions in args" do
      defmodule FredFlintstone do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset_with_fn_arg(:help, &foo/1)
        end

        defp foo(bar) do
          "Yabbadabbadoo: #{bar}"
        end
      end
    end

    test "entities support references to functions in option setters" do
      defmodule GhostBusters do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset(:catchphrase, contacter: &do_contact/1, default_message: "ghostbusters")
        end

        defp do_contact(message) do
          "Who you gonna call: #{message}"
        end
      end

      assert [preset] = Spark.Test.Contact.Info.presets(GhostBusters)
      assert preset.default_message == "ghostbusters"

      assert {_, [fun: fun]} = preset.contacter

      assert fun.("Ghost Busters") ==
               "Who you gonna call: Ghost Busters"
    end

    test "optional values with defaults are set" do
      defmodule BoBurnham do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset_with_optional do
          end
        end
      end

      assert [preset] = Spark.Test.Contact.Info.presets(BoBurnham)
      assert preset.default_message == nil
      assert preset.name == :atom
    end

    test "optional values with defaults are set when there are required arguments before them" do
      defmodule DarrowOLykos do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset_with_one_optional :name do
          end
        end
      end

      assert [preset] = Spark.Test.Contact.Info.presets(DarrowOLykos)
      assert preset.default_message == "flubber"
      assert preset.name == :name
    end

    test "optional values with defaults are set when there are required arguments after them" do
      defmodule LunaLovegood do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset_with_first_optional("hello!") do
            contacter(fn x -> x end)
          end
        end
      end

      assert [preset] = Spark.Test.Contact.Info.presets(LunaLovegood)
      assert preset.default_message == "hello!"
      assert preset.name == :atom
    end

    test "optional values can be included without including all of them" do
      defmodule BugsBunny do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset_with_optional(:name)
        end
      end

      assert [preset] = Spark.Test.Contact.Info.presets(BugsBunny)
      assert preset.default_message == nil
      assert preset.name == :name
    end

    test "optional values can be included without including all of them even with a do block" do
      defmodule ElmerFudd do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset_with_optional(:name) do
          end
        end
      end

      assert [preset] = Spark.Test.Contact.Info.presets(ElmerFudd)
      assert preset.default_message == nil
      assert preset.name == :name
    end

    test "all optional values can be included" do
      defmodule DaffyDuck do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset_with_optional(:name, "foo")
        end
      end

      assert [preset] = Spark.Test.Contact.Info.presets(DaffyDuck)
      assert preset.default_message == "foo"
      assert preset.name == :name
    end

    test "quoted values are stored" do
      defmodule HarryPotter do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset_with_quoted(name <> "fred")
        end
      end

      assert [preset] = Spark.Test.Contact.Info.presets(HarryPotter)

      assert strip_meta(preset.name) ==
               strip_meta(
                 quote do
                   name <> "fred"
                 end
               )
    end

    test "verifiers are run" do
      import ExUnit.CaptureIO

      base_line = __ENV__.line

      message =
        capture_io(:stderr, fn ->
          defmodule Gandalf do
            @moduledoc false
            use Spark.Test.Contact

            personal_details do
              # Line offset: +10
              first_name("Gandalf")
            end
          end
        end)

      assert message =~ "Cannot be gandalf"
      assert message =~ "(defined in test/dsl_test.exs:#{base_line + 10}:)"
      assert message =~ "~~~"
    end

    test "extensions can add entities to other entities extensions" do
      defmodule MartyMcfly do
        @moduledoc false
        use Spark.Test.Contact,
          extensions: [Spark.Test.ContactPatcher]

        presets do
          preset(:foo)
          special_preset(:bar)
        end
      end

      assert [preset, special_preset] = Spark.Test.Contact.Info.presets(MartyMcfly)
      assert preset.name == :foo
      refute preset.special?
      assert special_preset.name == :bar
      assert special_preset.special?
    end

    test "identifiers are honored" do
      import ExUnit.CaptureIO

      assert capture_io(:stderr, fn ->
               defmodule Squidward do
                 use Spark.Test.Contact

                 presets do
                   preset(:foo)
                   preset(:foo)
                 end
               end
             end) =~ "Got duplicate Spark.Test.Contact.Dsl.Preset: foo"
    end

    test "singleton entities are validated" do
      assert_raise Spark.Error.DslError, ~r/Expected a single singleton, got 2/, fn ->
        defmodule RickSanchez do
          @moduledoc false
          use Spark.Test.Contact

          presets do
            preset :foo do
              singleton(:bar)
              singleton(:baz)
            end
          end
        end
      end
    end
  end

  describe "annotation tracking" do
    test "section annotations are captured" do
      base_line = __ENV__.line

      defmodule SectionAnnoTest do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset(:test_preset)
        end

        contact do
          module(Some.Module)
        end
      end

      dsl_state = SectionAnnoTest.spark_dsl_config()

      # Check section annotation for :presets (sections are stored with list keys)
      presets_anno = Spark.Dsl.Extension.get_section_anno(dsl_state, [:presets])
      assert presets_anno != nil
      assert :erl_anno.location(presets_anno) == base_line + 6
      assert :erl_anno.file(presets_anno) == String.to_charlist(__ENV__.file)

      # Check section annotation for :contact
      contact_anno = Spark.Dsl.Extension.get_section_anno(dsl_state, [:contact])
      assert contact_anno != nil
      assert :erl_anno.location(contact_anno) == base_line + 10
      assert :erl_anno.file(contact_anno) == String.to_charlist(__ENV__.file)

      # Check end_location if available (OTP 28+)
      if function_exported?(:erl_anno, :end_location, 1) do
        presets_end = :erl_anno.end_location(presets_anno)
        contact_end = :erl_anno.end_location(contact_anno)

        # Sections should have end locations that are at or after their start
        assert presets_end >= base_line + 6
        assert contact_end >= base_line + 10
      end
    end

    test "option annotations are captured as keyword list" do
      base_line = __ENV__.line

      defmodule OptionAnnoTest do
        @moduledoc false
        use Spark.Test.Contact

        personal_details do
          first_name("John")
          last_name("Doe")
          # Line offset: +10
          nicknames([
            "Johnny",
            "J-Dog"
          ])
        end

        contact do
          module(Some.Module)
        end
      end

      dsl_state = OptionAnnoTest.spark_dsl_config()

      # Check option annotations for personal_details using introspection functions
      first_name_anno =
        Spark.Dsl.Extension.get_opt_anno(dsl_state, [:personal_details], :first_name)

      assert first_name_anno != nil
      assert :erl_anno.location(first_name_anno) == base_line + 7
      assert :erl_anno.file(first_name_anno) == String.to_charlist(__ENV__.file)

      last_name_anno =
        Spark.Dsl.Extension.get_opt_anno(dsl_state, [:personal_details], :last_name)

      assert last_name_anno != nil
      assert :erl_anno.location(last_name_anno) == base_line + 8
      assert :erl_anno.file(last_name_anno) == String.to_charlist(__ENV__.file)

      nicknames_anno =
        Spark.Dsl.Extension.get_opt_anno(dsl_state, [:personal_details], :nicknames)

      assert nicknames_anno != nil
      assert :erl_anno.location(nicknames_anno) == base_line + 10

      # Options don't have end locations since they're passed as a value and not
      # as AST

      # Check option annotations for contact
      module_anno = Spark.Dsl.Extension.get_opt_anno(dsl_state, [:contact], :module)
      assert module_anno != nil
      assert :erl_anno.location(module_anno) == base_line + 17
    end

    test "entities capture exact file and line information" do
      base_line = __ENV__.line

      defmodule EntityAnnoTest do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          # Line offset: +8
          preset :first do
            default_message("first")
          end

          # Line offset: +13
          preset :second do
            default_message("second")
          end
        end
      end

      dsl_state = EntityAnnoTest.spark_dsl_config()
      entities = Spark.Dsl.Extension.get_entities(dsl_state, [:presets])

      [first, second] = Enum.sort_by(entities, & &1.name)

      assert :erl_anno.location(first.anno) == base_line + 8
      assert :erl_anno.location(second.anno) == base_line + 13

      assert :erl_anno.file(first.anno) == String.to_charlist(__ENV__.file)
      assert :erl_anno.file(second.anno) == String.to_charlist(__ENV__.file)
    end

    test "nested entities capture annotations" do
      base_line = __ENV__.line

      defmodule NestedEntityAnnoTest do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          # Line offset: +8
          preset :parent do
            # Line offset: +10
            singleton(:child_entity)
          end
        end
      end

      dsl_state = NestedEntityAnnoTest.spark_dsl_config()
      [entity | _] = Spark.Dsl.Extension.get_entities(dsl_state, [:presets])

      assert :erl_anno.location(entity.anno) == base_line + 8
      assert :erl_anno.file(entity.anno) == String.to_charlist(__ENV__.file)

      assert :erl_anno.location(entity.singleton.anno) == base_line + 10
      assert :erl_anno.file(entity.singleton.anno) == String.to_charlist(__ENV__.file)
    end

    test "annotations include end_location when available (OTP 28+)" do
      base_line = __ENV__.line

      defmodule EndLocationTest do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          # Line offset: +8
          preset :with_block do
            default_message("start")
            # more content
          end

          # Line offset: +14
        end
      end

      dsl_state = EndLocationTest.spark_dsl_config()
      entities = Spark.Dsl.Extension.get_entities(dsl_state, [:presets])

      [entity | _] = entities
      assert :erl_anno.location(entity.anno) == base_line + 8

      # Check if end_location is supported and set
      if function_exported?(:erl_anno, :set_end_location, 1) do
        end_location = :erl_anno.end_location(entity.anno)

        # Should be at or after start
        assert end_location >= base_line + 8
        # Should be before end
        assert end_location <= base_line + 14
      end
    end

    test "fragments preserve original source location annotations" do
      # Test with the existing TedDansenFragment which defines address options
      dsl_state = TedDansen.spark_dsl_config()

      # Check that the fragment's configuration is included
      {:ok, street} = TedDansen.fetch_opt([:address], :street)
      assert street == "foobar"

      # Create a test with entities in fragments
      defmodule TestFragment do
        @moduledoc false
        use Spark.Dsl.Fragment, of: Spark.Test.Contact

        presets do
          # Line 6 in this context
          preset :fragment_preset do
            default_message("from fragment")
          end
        end
      end

      defmodule TestWithFragment do
        @moduledoc false
        use Spark.Test.Contact, fragments: [TestFragment]

        presets do
          preset :main_preset do
            default_message("from main")
          end
        end
      end

      dsl_state = TestWithFragment.spark_dsl_config()
      entities = Spark.Dsl.Extension.get_entities(dsl_state, [:presets])

      assert length(entities) == 2

      fragment_entity = Enum.find(entities, &(&1.name == :fragment_preset))
      main_entity = Enum.find(entities, &(&1.name == :main_preset))

      assert String.to_charlist(__ENV__.file) == :erl_anno.file(fragment_entity.anno)
      assert String.to_charlist(__ENV__.file) == :erl_anno.file(main_entity.anno)
    end

    test "introspection functions can extract annotations" do
      base_line = __ENV__.line

      defmodule IntrospectionTest do
        @moduledoc false
        use Spark.Test.Contact

        personal_details do
          first_name("Alice")
          last_name("Smith")
        end

        presets do
          preset(:test_preset)
        end
      end

      dsl_state = IntrospectionTest.spark_dsl_config()

      # Test get_section_anno function
      personal_details_anno = Spark.Dsl.Extension.get_section_anno(dsl_state, [:personal_details])
      assert :erl_anno.location(personal_details_anno) == base_line + 6
      assert :erl_anno.file(personal_details_anno) == String.to_charlist(__ENV__.file)

      # Test get_opt_anno function
      first_name_anno =
        Spark.Dsl.Extension.get_opt_anno(dsl_state, [:personal_details], :first_name)

      assert :erl_anno.location(first_name_anno) == base_line + 7

      last_name_anno =
        Spark.Dsl.Extension.get_opt_anno(dsl_state, [:personal_details], :last_name)

      assert :erl_anno.location(last_name_anno) == base_line + 8

      # Test get_entities_with_anno returns entities with their annotations intact
      entities = Spark.Dsl.Extension.get_entities(dsl_state, [:presets])
      assert length(entities) == 1
      [entity] = entities
      assert :erl_anno.location(entity.anno) == base_line + 12
    end

    test "entity annotations can be accessed via introspection regardless of anno_field" do
      base_line = __ENV__.line

      defmodule EntityIntrospectionTest do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          # Line offset: +8
          preset :first do
            default_message("first")
          end

          # Line offset: +13
          preset :second do
            default_message("second")
          end
        end
      end

      dsl_state = EntityIntrospectionTest.spark_dsl_config()

      # Test get_entities_anno function - gets all annotations
      entities_anno = Spark.Dsl.Extension.get_entities_anno(dsl_state, [:presets])
      assert length(entities_anno) == 2

      [first_anno, second_anno] = entities_anno
      assert first_anno != nil
      assert second_anno != nil
      assert :erl_anno.location(first_anno) == base_line + 8
      assert :erl_anno.location(second_anno) == base_line + 13

      # Test get_entity_anno function - gets specific annotation by index
      first_entity_anno = Spark.Dsl.Extension.get_entity_anno(dsl_state, [:presets], 0)
      second_entity_anno = Spark.Dsl.Extension.get_entity_anno(dsl_state, [:presets], 1)

      assert :erl_anno.location(first_entity_anno) == base_line + 8
      assert :erl_anno.location(second_entity_anno) == base_line + 13

      # Test that annotations are available even for entities without anno_field
      # (since not all entity types define an anno_field)
      assert first_entity_anno != nil
      assert second_entity_anno != nil
    end

    test "entities with required arguments don't assume an argument is opts if its a keyword list" do
      defmodule BethSanchez do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset :foo do
            singleton(foo: :bar)
          end
        end
      end

      assert [%{singleton: %Spark.Test.Contact.Dsl.Singleton{value: [foo: :bar]}}] =
               Spark.Test.Contact.Info.presets(BethSanchez)
    end

    test "singleton entities are unwrapped" do
      defmodule MortySanchez do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset :foo do
            singleton(:bar)
          end
        end
      end

      assert [%{singleton: %Spark.Test.Contact.Dsl.Singleton{value: :bar}}] =
               Spark.Test.Contact.Info.presets(MortySanchez)
    end

    test "extensions honor identifiers when adding entities to other entities extensions" do
      import ExUnit.CaptureIO

      assert capture_io(:stderr, fn ->
               defmodule Doc do
                 @moduledoc false
                 use Spark.Test.Contact,
                   extensions: [Spark.Test.ContactPatcher]

                 presets do
                   preset(:foo)
                   special_preset(:foo)
                 end
               end
             end) =~ "Got duplicate Spark.Test.Contact.Dsl.Preset: foo"
    end
  end

  describe "optional entity arguments" do
    test "optional arguments can be supplied either as arguments or as dsl options" do
      defmodule OptionEinstein do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset_with_optional :einstein do
            default_message("Woof!")
          end
        end
      end

      assert [%{name: :einstein, default_message: "Woof!"}] =
               Spark.Test.Contact.Info.presets(OptionEinstein)
    end

    test "optional arguments can be supplied either as argument or as keyword arguments" do
      defmodule KeywordEinstein do
        @moduledoc false
        use Spark.Test.Contact

        presets do
          preset_with_optional(:einstein, default_message: "Woof!")
        end
      end

      assert [%{name: :einstein, default_message: "Woof!"}] =
               Spark.Test.Contact.Info.presets(KeywordEinstein)
    end

    test "optional arguments cannot be supplied both as an argument and as an option" do
      assert_raise Spark.Error.DslError,
                   ~r/Multiple values for key/,
                   fn ->
                     defmodule ArgAndOptionEinstein do
                       @moduledoc false
                       use Spark.Test.Contact

                       presets do
                         preset_with_optional :einstein, "Woof!" do
                           default_message("Woof!")
                         end
                       end
                     end
                   end
    end

    test "optional arguments cannot be supplied both as an argument and as a keyword" do
      assert_raise Spark.Error.DslError,
                   ~r/Multiple values for key/,
                   fn ->
                     defmodule ArgAndKeywordEinstein do
                       @moduledoc false
                       use Spark.Test.Contact

                       presets do
                         preset_with_optional(:einstein, "Woof!", default_message: "Woof!")
                       end
                     end
                   end
    end

    test "optional arguments cannot be supplied both as a keyword and as an option" do
      assert_raise Spark.Error.DslError,
                   ~r/Multiple values for key/,
                   fn ->
                     defmodule OptionAndKeywordEinstein do
                       @moduledoc false
                       use Spark.Test.Contact

                       presets do
                         preset_with_optional :einstein, default_message: "Woof!" do
                           default_message("Woof!")
                         end
                       end
                     end
                   end
    end
  end

  test "predicate options correctly compile" do
    assert {_, _, filename} =
             :code.get_object_code(:"Elixir.Spark.Test.Contact.Dsl.AwesomeQuestionMark.Options")

    refute to_string(filename) =~ "?"
  end

  describe "DSL default options" do
    defmodule DefaultOptionExtension do
      @moduledoc false
      @section %Spark.Dsl.Section{
        name: :example,
        schema: [
          opt_with_default: [
            type: :atom,
            required: false,
            default: :default
          ],
          opt_without_default: [
            type: :atom,
            required: false
          ]
        ]
      }

      use Spark.Dsl.Extension, sections: [@section]
    end

    defmodule ExampleDsl do
      @moduledoc false
      use Spark.Dsl, default_extensions: [extensions: DefaultOptionExtension]
    end

    test "defaults are applied when any option is set" do
      defmodule AnyOptionSet do
        @moduledoc false
        use ExampleDsl

        example do
          opt_without_default(:marty)
        end
      end

      assert :default == Spark.Dsl.Extension.get_opt(AnyOptionSet, [:example], :opt_with_default)
    end

    test "defaults are applied when the section is present but empty" do
      defmodule NoOptionSet do
        @moduledoc false
        use ExampleDsl

        example do
        end
      end

      assert :default == Spark.Dsl.Extension.get_opt(NoOptionSet, [:example], :opt_with_default)
    end
  end

  describe "error location tracking" do
    test "duplicate entity errors include location information" do
      import ExUnit.CaptureIO

      error_output =
        capture_io(:stderr, fn ->
          try do
            defmodule LocationTestDuplicate do
              use Spark.Test.Contact

              presets do
                preset(:duplicate_test)
                preset(:duplicate_test)
              end
            end
          rescue
            _ -> :ok
          end
        end)

      # Should include the file and line information
      assert error_output =~ "dsl_test.exs"
      assert error_output =~ "Got duplicate"
    end

    test "schema validation errors include location information" do
      try do
        defmodule LocationTestSchema do
          use Spark.Dsl.Fragment, of: Spark.Test.Contact

          personal_details do
            # This should trigger a schema validation error during compilation
            # when the section is processed, because first_name is required
          end
        end

        _ = LocationTestSchema.spark_dsl_config()
      rescue
        error ->
          # The error should include location information
          error_message = Exception.message(error)
          assert error_message =~ "dsl_test.exs"
      end
    end
  end
end
