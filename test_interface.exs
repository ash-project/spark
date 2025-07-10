#!/usr/bin/env elixir

# Test script for Spark.Dsl.Interface

# Ensure test modules are compiled
Code.require_file("test/support/contact/contact.ex", __DIR__)

# First, let's test the basic interface functionality
IO.puts("Testing Spark.Dsl.Interface...")

alias Spark.Dsl.Interface.Placeholder

# Test Placeholder
placeholder = Placeholder.new(:test, :string, "Test description")
IO.puts("Created placeholder: #{inspect(placeholder)}")
IO.puts("Is placeholder?: #{Placeholder.placeholder?(placeholder)}")
IO.puts("Is string placeholder?: #{Placeholder.placeholder?("not a placeholder")}")

# Test Interface definition
defmodule TestInterface do
  use Spark.Dsl.Interface, for: Spark.Test.Contact

  address do
    street("123 Test St")
  end
end

IO.puts("Interface defined successfully!")
IO.puts("Interface for: #{inspect(TestInterface.interface_for())}")
IO.puts("Is interface?: #{TestInterface.is_interface?()}")

required_values = TestInterface.required_values()
IO.puts("Required values: #{inspect(required_values)}")

# Test the schema issue - let's see what happens when we try to use interfaces option
IO.puts("\nTesting DSL with interfaces option...")

# Test just the option parsing first
try do
  defmodule TestResourceBasic do
    use Spark.Test.Contact, interfaces: []
  end
  
  IO.puts("SUCCESS: Empty interfaces option works!")
rescue
  e ->
    IO.puts("ERROR with empty interfaces: #{inspect(e)}")
    IO.puts("Message: #{Exception.message(e)}")
end

# Test with an actual interface that should pass
try do
  defmodule TestResourceWithInterface do
    use Spark.Test.Contact, interfaces: [TestInterface]
    
    address do
      street("123 Test St")
    end
    
    personal_details do
      first_name("Test")
    end
  end
  
  IO.puts("SUCCESS: Resource with matching interface compiled!")
rescue
  e ->
    IO.puts("ERROR with matching interface: #{inspect(e)}")
    IO.puts("Message: #{Exception.message(e)}")
end

# Test with an interface that should fail
try do
  defmodule TestResourceWithBadInterface do
    use Spark.Test.Contact, interfaces: [TestInterface]
    
    address do
      street("Different Street")  # This should fail validation
    end
    
    personal_details do
      first_name("Test")
    end
  end
  
  IO.puts("ERROR: Resource with non-matching interface should have failed!")
rescue
  e ->
    IO.puts("SUCCESS: Resource with non-matching interface correctly failed!")
    IO.puts("Error: #{Exception.message(e)}")
end

IO.puts("\nTest completed!")