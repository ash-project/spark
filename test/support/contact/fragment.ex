defmodule Spark.Test.Contact.TedDansenFragment do
  @moduledoc false
  use Spark.Dsl.Fragment, of: Spark.Test.Contact

  address do
    street("foobar")
  end
end
