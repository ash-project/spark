# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.TopLevel.Info do
  @moduledoc false
  use Spark.InfoGenerator, extension: Spark.Test.TopLevel.Dsl, sections: [:steps]
end
