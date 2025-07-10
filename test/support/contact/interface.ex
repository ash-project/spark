defmodule Spark.Test.Contact.Interface do
  @moduledoc false
  use Spark.Dsl.Interface, for: Spark.Test.Contact


  address do
    # Required: street must be present in implementing resources
    street("123 Main St")
  end
end