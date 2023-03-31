defmodule Spark.Test.Recursive.Info do
  @moduledoc false
  use Spark.InfoGenerator, extension: Spark.Test.Recursive.Dsl, sections: [:steps]
end
