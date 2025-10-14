# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.TopLevel.Info do
  @moduledoc false
  use Spark.InfoGenerator, extension: Spark.Test.TopLevel.Dsl, sections: [:steps]
end
