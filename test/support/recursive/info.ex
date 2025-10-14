# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.Recursive.Info do
  @moduledoc false
  use Spark.InfoGenerator, extension: Spark.Test.Recursive.Dsl, sections: [:steps]
end
