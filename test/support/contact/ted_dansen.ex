# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule TedDansen do
  @moduledoc "Stuff"
  use Spark.Test.Contact, fragments: [Spark.Test.Contact.TedDansenFragment]

  alias Foo.Bar, as: Bar
  alias Foo.Bar, as: Buz

  contact do
    module(Bar.Baz)
    module(Buz)
  end

  personal_details do
    first_name("Ted")

    last_name("Dansen")
  end
end
