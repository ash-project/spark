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
           ] = suggestions(buffer, cursor)
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
