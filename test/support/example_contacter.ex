defmodule ExampleContacter do
  @moduledoc false
  @behaviour Spark.Test.Contact.Contacter
  def contact(_, _), do: {:ok, "contacted"}
end

defmodule Spark.Test.ContacterBuiltins do
  @moduledoc false
  def example, do: {ExampleContacter, []}
end
