defmodule Spark.InterfaceTest do
  use ExUnit.Case, async: true

  alias Spark.Dsl.Interface.Placeholder

  describe "Interface.Placeholder" do
    test "creates a placeholder struct" do
      placeholder = Placeholder.new()
      assert %Placeholder{key: nil, type: nil, description: nil} = placeholder
    end

    test "creates a placeholder with metadata" do
      placeholder = Placeholder.new(:name, :string, "The name field")
      assert %Placeholder{key: :name, type: :string, description: "The name field"} = placeholder
    end

    test "placeholder?/1 identifies placeholders" do
      assert Placeholder.placeholder?(%Placeholder{})
      refute Placeholder.placeholder?("not a placeholder")
      refute Placeholder.placeholder?(%{})
    end
  end

  describe "Interface module" do
    test "interface can be defined" do
      defmodule TestInterface do
        use Spark.Dsl.Interface, for: Spark.Test.Contact

        address do
          street("123 Main St")
        end
      end

      assert TestInterface.is_interface?()
      assert TestInterface.interface_for() == Spark.Test.Contact
      
      # Interface should have required values
      required_values = TestInterface.required_values()
      assert length(required_values) > 0
      
      # Check that street is a required value
      street_required = Enum.any?(required_values, fn
        {:option, [:address], :street, "123 Main St"} -> true
        _ -> false
      end)
      
      assert street_required
    end
  end
end