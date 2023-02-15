defmodule Spark.Rewrite do
  import Spark.Patcher

  def extend_spark(code, spark, name, type) do
    name = Module.concat([name])
    type = String.to_atom(type)
    single? = name in spark.single_extension_kinds()

    if single? do
      code
      |> parse_string!()
      |> enter_defmodule()
      |> halt_if(& &1, :already_patched)
    else
      code
      |> parse_string!()
      |> enter_defmodule()
      |> enter_call(:use, fn args ->
        false
      end)
      |> halt_if(& &1, :already_patched)
    end
  end
end
