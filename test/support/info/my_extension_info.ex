defmodule MyExtension.Info do
  use Spark.InfoGenerator, extension: MyExtension, sections: [:my_section]
end
