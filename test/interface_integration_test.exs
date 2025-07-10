defmodule Spark.InterfaceIntegrationTest do
  use ExUnit.Case, async: true


  describe "Interface integration with DSL" do
    test "resource can implement interface successfully" do
      defmodule TestInterface do
        use Spark.Dsl.Interface, for: Spark.Test.Contact

        address do
          street("123 Main St")
        end
      end

      # This should compile successfully since it implements the interface
      defmodule TestResource do
        use Spark.Test.Contact, interfaces: [TestInterface]

        address do
          street("123 Main St")
        end

        personal_details do
          first_name("John")
        end
      end

      # Verify the resource compiled successfully
      assert TestResource.spark_is() == Spark.Test.Contact
    end

    test "resource with missing interface values fails to compile" do
      defmodule TestInterfaceMissing do
        use Spark.Dsl.Interface, for: Spark.Test.Contact

        address do
          street("456 Oak Ave")
        end
      end

      # This should fail to compile since it doesn't implement the interface
      assert_raise RuntimeError, ~r/does not implement interface/, fn ->
        defmodule TestResourceMissing do
          use Spark.Test.Contact, interfaces: [TestInterfaceMissing]

          personal_details do
            first_name("Jane")
          end
        end
      end
    end

    test "resource with different interface values fails to compile" do
      defmodule TestInterfaceDifferent do
        use Spark.Dsl.Interface, for: Spark.Test.Contact

        address do
          street("789 Pine St")
        end
      end

      # This should fail to compile since it has a different street value
      assert_raise RuntimeError, ~r/does not implement interface/, fn ->
        defmodule TestResourceDifferent do
          use Spark.Test.Contact, interfaces: [TestInterfaceDifferent]

          address do
            street("Different Street")
          end

          personal_details do
            first_name("Bob")
          end
        end
      end
    end
  end
end