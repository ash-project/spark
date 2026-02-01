# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
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
