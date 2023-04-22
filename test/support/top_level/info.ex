defmodule Spark.Test.TopLevel.Info do
  @moduledoc false
  use Spark.InfoGenerator, extension: Spark.Test.TopLevel.Dsl, sections: [:steps]
end
