defmodule TedDansen do
  @moduledoc "Stuff"
  use Spark.Test.Contact

  alias Foo.Bar

  contact do
    module(Bar)
  end

  personal_details do
    first_name("Ted")

    last_name("Dansen")
  end
end
