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

  describe "{:function, ...} type" do
    test "compiles and generates info functions for {:function, args: [...], returns: ...}" do
      assert :error = Info.my_section_callback(Resource)
    end

    test "compiles when used inside {:or, ...}" do
      assert :error = Info.my_section_handler(Resource)
    end
  end

  describe "{:function, ...} type validation" do
    test "accepts args with returns" do
      assert {:ok, {:function, args: [:map], returns: :string}} =
               Spark.Options.validate_type({:function, args: [:map], returns: :string})
    end

    test "accepts arity only" do
      assert {:ok, {:function, arity: 2}} =
               Spark.Options.validate_type({:function, arity: 2})
    end

    test "accepts args only" do
      assert {:ok, {:function, args: [:string, :integer]}} =
               Spark.Options.validate_type({:function, args: [:string, :integer]})
    end

    test "accepts arity with matching args" do
      assert {:ok, {:function, arity: 2, args: [:map, :string]}} =
               Spark.Options.validate_type({:function, arity: 2, args: [:map, :string]})
    end

    test "accepts returns only" do
      assert {:ok, {:function, returns: :string}} =
               Spark.Options.validate_type({:function, returns: :string})
    end

    test "rejects mismatched arity and args" do
      assert {:error, message} =
               Spark.Options.validate_type({:function, arity: 3, args: [:map, :string]})

      assert message =~ "args length"
    end

    test "rejects invalid keys" do
      assert {:error, message} =
               Spark.Options.validate_type({:function, foo: :bar})

      assert message =~ "invalid keys"
    end

    test "rejects negative arity" do
      assert {:error, message} =
               Spark.Options.validate_type({:function, arity: -1})

      assert message =~ "non-negative integer"
    end

    test "rejects non-integer arity" do
      assert {:error, message} =
               Spark.Options.validate_type({:function, arity: :two})

      assert message =~ "non-negative integer"
    end

    test "rejects non-list args" do
      assert {:error, message} =
               Spark.Options.validate_type({:function, args: :map})

      assert message =~ "list of types"
    end

    test "validates nested arg types" do
      assert {:error, _} =
               Spark.Options.validate_type({:function, args: [:not_a_real_type]})
    end

    test "validates nested return type" do
      assert {:error, _} =
               Spark.Options.validate_type({:function, returns: :not_a_real_type})
    end
  end

  describe "{:function, ...} runtime validation" do
    test "accepts a function matching arity from args" do
      schema = [cb: [type: {:function, args: [:map], returns: :string}]]
      assert {:ok, _} = Spark.Options.validate([cb: fn _ -> "ok" end], schema)
    end

    test "accepts a function matching explicit arity" do
      schema = [cb: [type: {:function, arity: 2}]]
      assert {:ok, _} = Spark.Options.validate([cb: fn _, _ -> :ok end], schema)
    end

    test "rejects a function with wrong arity" do
      schema = [cb: [type: {:function, args: [:map], returns: :string}]]
      assert {:error, _} = Spark.Options.validate([cb: fn -> "ok" end], schema)
    end

    test "rejects non-function values" do
      schema = [cb: [type: {:function, args: [:map]}]]
      assert {:error, _} = Spark.Options.validate([cb: "not_a_function"], schema)
    end

    test "works inside {:or, ...} at runtime" do
      schema = [cb: [type: {:or, [:string, {:function, args: [:map]}]}]]
      assert {:ok, _} = Spark.Options.validate([cb: "a string"], schema)
      assert {:ok, _} = Spark.Options.validate([cb: fn _ -> :ok end], schema)
      assert {:error, _} = Spark.Options.validate([cb: 42], schema)
    end
  end

  describe "{:function, ...} documentation" do
    test "dsl_docs_type with args and returns" do
      assert "(map -> String.t)" =
               Spark.Options.Docs.dsl_docs_type({:function, args: [:map], returns: :string})
    end

    test "dsl_docs_type with args only" do
      assert "(map, String.t -> any)" =
               Spark.Options.Docs.dsl_docs_type({:function, args: [:map, :string]})
    end

    test "dsl_docs_type with arity only" do
      assert "(any, any -> any)" =
               Spark.Options.Docs.dsl_docs_type({:function, arity: 2})
    end

    test "dsl_docs_type with zero arity" do
      assert "(-> any)" =
               Spark.Options.Docs.dsl_docs_type({:function, arity: 0})
    end

    test "dsl_docs_type with returns only" do
      assert "(... -> any)" =
               Spark.Options.Docs.dsl_docs_type({:function, returns: :string})
    end
  end
end
