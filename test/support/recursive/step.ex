# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.Step do
  @moduledoc false
  defstruct [:name, :number, :__identifier__, :__spark_metadata__, steps: []]
end
