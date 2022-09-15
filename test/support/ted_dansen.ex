defmodule TedDansen do
  @moduledoc false
  use Spark.Test.Contact

  personal_details do
    first_name("Ted")

    last_name("Dansen")
  end
end
