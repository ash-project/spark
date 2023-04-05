defmodule Spark.Test.Contact.TedDansenFragment do
  use Spark.Dsl.Fragment, of: Spark.Test.Contact

  address do
    street("foobar")
  end
end
