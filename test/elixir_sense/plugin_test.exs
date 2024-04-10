defmodule Spark.ElixirSense.PluginTest do
  use ExUnit.Case

  def cursors(text) do
    {_, cursors} =
      ElixirSense.Core.Source.walk_text(text, {false, []}, fn
        "#", rest, _, _, {_comment?, cursors} ->
          {rest, {true, cursors}}

        "\n", rest, _, _, {_comment?, cursors} ->
          {rest, {false, cursors}}

        "^", rest, line, col, {true, cursors} ->
          {rest, {true, [%{line: line - 1, col: col} | cursors]}}

        _, rest, _, _, acc ->
          {rest, acc}
      end)

    Enum.reverse(cursors)
  end

  def suggestions(buffer, cursor) do
    ElixirSense.suggestions(buffer, cursor.line, cursor.col)
  end

  def suggestions(buffer, cursor, type) do
    suggestions(buffer, cursor)
    |> Enum.filter(fn s -> s.type == type end)
  end

  def suggestions_by_kind(buffer, cursor, kind) do
    suggestions(buffer, cursor)
    |> Enum.filter(fn s -> s[:kind] == kind end)
  end

  test "suggesting patched entities" do
    buffer = """
    defmodule MartyMcfly do
      use Spark.Test.Contact,
        extensions: [Spark.Test.ContactPatcher]

      presets do
        spec
        #   ^
      end
    end
    """

    [cursor] = cursors(buffer)

    result = suggestions(buffer, cursor)

    assert [
             %{
               detail: "Dsl Entity",
               documentation: "",
               kind: :function,
               label: "special_preset",
               snippet: "special_preset ${1:name}",
               type: :generic
             }
           ] = result
  end

  test "entity snippets are correctly shown" do
    buffer = """
    defmodule DocBrown do
      use Spark.Test.Contact

      presets do
        preset_with_snip
        #               ^
      end
    end
    """

    [cursor] = cursors(buffer)
    result = suggestions(buffer, cursor)

    assert [%{snippet: "preset_with_snippet ${1::doc_brown}"}] = result
  end

  test "entity snippets are correctly shown when parenthesis are involved" do
    buffer = """
    defmodule DocBrown do
      use Spark.Test.Contact

      presets do
        preset_with_snippet :foo, bar() do

    #     ^
        end
      end
    end
    """

    [cursor] = cursors(buffer)

    assert [
             %{
               label: "thing",
               type: :generic,
               kind: :function,
               detail: "Option",
               documentation: "",
               snippet: "thing \"$0\""
             }
           ] = Enum.take(suggestions(buffer, cursor), 1)
  end

  test "entity snippets are correctly shown when parenthesis are involved, using options" do
    buffer = """
    defmodule DocBrown do
      use Spark.Test.Contact

      presets do
        preset_with_snippet :foo, bar(),
    #                                    ^
        end
      end
    end
    """

    [cursor] = cursors(buffer)

    assert [
             %{
               label: "thing",
               type: :generic,
               kind: :function,
               detail: "Option",
               documentation: "",
               snippet: "thing: \"$0\""
             }
           ] = Enum.take(suggestions(buffer, cursor), 1)
  end

  test "entity snippets show arguments before options" do
    buffer = """
    defmodule DocBrown do
      use Spark.Test.Contact

      presets do
        preset_with_fn_arg :foo,
    #                            ^
        end
      end
    end
    """

    [cursor] = cursors(buffer)

    assert [
             %{
               label: "ExampleContacter",
               type: :generic,
               kind: :class,
               insert_text: "ExampleContacter",
               detail: "Spark.Test.Contact.Contacter",
               documentation: ""
             },
             %{
               args: "",
               arity: 0,
               name: "example",
               type: :function,
               origin: "Spark.Test.ContacterBuiltins",
               spec: "",
               metadata: %{app: :spark},
               args_list: [],
               summary: "",
               snippet: nil,
               def_arity: 0,
               visibility: :public,
               needed_import: nil,
               needed_require: nil
             }
           ] = Enum.sort(suggestions(buffer, cursor))
  end

  describe "using opts" do
    test "opts to `__using__` are autocompleted" do
      buffer = """
      defmodule DocBrown do
        use Spark.Test.Contact, otp_
      #                             ^
      end
      """

      [cursor] = cursors(buffer)

      assert [
               %{
                 label: "otp_app",
                 type: :generic,
                 kind: :function,
                 snippet: "otp_app: :$0",
                 detail: "Option",
                 documentation: "The otp_app to use for any application configurable options"
               }
             ] = suggestions(buffer, cursor)
    end

    test "opts to `__using__` are autocompleted in other formats" do
      buffer = """
      defmodule DocBrown do
        use Spark.Test.Contact,
          thing: :foo,
          otp_
      #       ^
      end
      """

      [cursor] = cursors(buffer)

      assert [
               %{
                 label: "otp_app",
                 type: :generic,
                 kind: :function,
                 snippet: "otp_app: :$0",
                 detail: "Option",
                 documentation: "The otp_app to use for any application configurable options"
               }
             ] = suggestions(buffer, cursor)
    end

    defmodule Foo do
      use Spark.Dsl.Extension
    end

    test "opts to `__using__` are autocompleted with value types" do
      buffer = """
      defmodule DocBrown do
        use Spark.Test.Contact, extensions: []
      #                                      ^
      end
      """

      [cursor] = cursors(buffer)

      suggestions =
        buffer
        |> suggestions(cursor)
        |> Enum.map(& &1.insert_text)
        |> Enum.take(4)
        |> Enum.sort()

      assert suggestions ==
               Enum.sort([
                 "Spark.Test.Contact.Dsl",
                 "Spark.Test.Recursive.Dsl",
                 "Spark.Test.TopLevel.Dsl",
                 "Spark.Test.ContactPatcher"
               ])
    end
  end

  describe "function that accepts a spark option schema" do
    test "it autocompletes the opts" do
      buffer = """
      ExampleOptions.func(1, 2, opt
      #                            ^
      """

      [cursor] = cursors(buffer)

      assert [
               %{
                 label: "option",
                 type: :generic,
                 kind: :function,
                 snippet: "option: \"$0\"",
                 detail: "Option",
                 documentation: "An option"
               }
             ] = suggestions(buffer, cursor)
    end

    test "it autocompletes the opts when piping" do
      buffer = """
      1
      |> ExampleOptions.func(2,
         opt
      #     ^
      """

      [cursor] = cursors(buffer)

      assert [
               %{
                 label: "option",
                 type: :generic,
                 kind: :function,
                 snippet: "option: \"$0\"",
                 detail: "Option",
                 documentation: "An option"
               }
             ] = suggestions(buffer, cursor)
    end

    test "it ignores maps" do
      buffer = """
      ExampleOptions.func(1, 2, %{opt
      #                              ^
      """

      [cursor] = cursors(buffer)

      assert [] = suggestions(buffer, cursor)
    end
  end
end
