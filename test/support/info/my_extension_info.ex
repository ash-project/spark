defmodule MyExtension.Info do
  @moduledoc false
  use Spark.InfoGenerator, extension: MyExtension, sections: [:my_section]
end
