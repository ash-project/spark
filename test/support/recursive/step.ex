# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.Step do
  @moduledoc false
  defstruct [:name, :number, :__identifier__, :__spark_metadata__, steps: []]
end
