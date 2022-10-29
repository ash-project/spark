defmodule Spark.Test.Contact.Contacter do
  @moduledoc false
  @callback contact(Spark.Test.Contact.t(), message :: String.t()) :: {:ok, term} | {:error, term}
end
