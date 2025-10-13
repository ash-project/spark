# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.Contact.TedDansenFragment do
  @moduledoc false
  use Spark.Dsl.Fragment, of: Spark.Test.Contact

  address do
    street("foobar")
  end
end
