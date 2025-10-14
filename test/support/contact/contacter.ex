# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.Contact.Contacter do
  @moduledoc false
  @callback contact(Spark.Test.Contact.t(), message :: String.t()) :: {:ok, term} | {:error, term}
end
