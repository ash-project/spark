# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.Contact.TedDansenFragment do
  @moduledoc false
  use Spark.Dsl.Fragment, of: Spark.Test.Contact

  address do
    street("foobar")
  end
end
