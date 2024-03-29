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
      assert_raise Spark.Error.DslError, ~r/Cannot be gandalf/, fn ->
        defmodule Gandalf do
          @moduledoc false
          use Spark.Test.Contact

          personal_details do
            first_name("Gandalf")
          end
        end
      end
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
      assert_raise Spark.Error.DslError,
                   ~r/Got duplicate Spark.Test.Contact.Dsl.Preset: foo/,
                   fn ->
                     defmodule Squidward do
                       use Spark.Test.Contact

                       presets do
                         preset(:foo)
                         preset(:foo)
                       end
                     end
                   end
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

      assert [%{singleton: %Spark.Test.Contact.Dsl.Singleton{value: [foo: :bar]}}] = Spark.Test.Contact.Info.presets(BethSanchez)
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
      assert_raise Spark.Error.DslError,
                   ~r/Got duplicate Spark.Test.Contact.Dsl.Preset: foo/,
                   fn ->
                     defmodule Doc do
                       @moduledoc false
                       use Spark.Test.Contact,
                         extensions: [Spark.Test.ContactPatcher]

                       presets do
                         preset(:foo)
                         special_preset(:foo)
                       end
                     end
                   end
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
end
