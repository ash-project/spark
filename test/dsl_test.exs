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

  describe "anonymous functions in DSL" do
    test "creates a function and passes it to the default" do
      defmodule ObiWan do
        use Spark.Test.Contact

        contact do
          contacter(fn message ->
            "Help me Obi-Wan Kenobi: #{message}"
          end)
        end
      end

      assert {Spark.Test.Contact.Contacter.Function, opts} =
               Spark.Test.Contact.Info.contacter(ObiWan)

      assert {m, f, a} = opts[:fun]

      assert apply(m, f, ["you're my only hope." | a]) ==
               "Help me Obi-Wan Kenobi: you're my only hope."
    end

    test "entities support functions in option setters" do
      defmodule PaulMcCartney do
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

      assert {_, [fun: {m, f, _a}]} = preset.contacter

      assert apply(m, f, ["Help"]) ==
               "Help: I need some body"
    end

    test "entities can functions in args" do
      defmodule FredFlintstone do
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
        use Spark.Test.Contact

        presets do
          preset :catchphrase do
            default_message("ghostbusters")

            contacter(&do_contact/1)
          end
        end

        defp do_contact(message) do
          "Who you gonna call: #{message}"
        end
      end

      assert [preset] = Spark.Test.Contact.Info.presets(GhostBusters)
      assert preset.default_message == "ghostbusters"

      assert {_, [fun: {m, f, _a}]} = preset.contacter

      assert apply(m, f, ["Ghost Busters"]) ==
               "Who you gonna call: Ghost Busters"
    end

    test "optional values with defaults are set" do
      defmodule BoBurnham do
        use Spark.Test.Contact

        presets do
          preset_with_optional()
        end
      end

      assert [preset] = Spark.Test.Contact.Info.presets(BoBurnham)
      assert preset.default_message == nil
      assert preset.name == :atom
    end

    test "optional values can be included without including all of them" do
      defmodule BugsBunny do
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
        use Spark.Test.Contact

        presets do
          preset_with_optional(:name, "foo")
        end
      end

      assert [preset] = Spark.Test.Contact.Info.presets(DaffyDuck)
      assert preset.default_message == "foo"
      assert preset.name == :name
    end

    test "verifiers are run" do
      assert_raise Spark.Error.DslError, ~r/Cannot be gandalf/, fn ->
        defmodule Gandalf do
          use Spark.Test.Contact

          personal_details do
            first_name("Gandalf")
          end
        end
      end
    end
  end
end
