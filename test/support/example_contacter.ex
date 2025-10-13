# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule ExampleContacter do
  @moduledoc false
  @behaviour Spark.Test.Contact.Contacter
  def contact(_, _), do: {:ok, "contacted"}
end

defmodule Spark.Test.ContacterBuiltins do
  @moduledoc false
  def example, do: {ExampleContacter, []}
end
