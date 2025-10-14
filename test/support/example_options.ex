# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule ExampleOptions do
  @moduledoc false
  @schema [
    option: [
      type: :string,
      doc: "An option"
    ]
  ]

  @doc "Some explanation"
  @doc spark_opts: [{2, @schema}]
  def func(a, b, opts \\ []) do
    with {:ok, opts} <- Spark.Options.validate(opts, @schema) do
      {a, b, opts}
    end
  end
end
