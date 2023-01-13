defmodule Spark.CodeHelpers do
  @moduledoc false

  def code_identifier(code) do
    code
    |> strip_meta()
    |> :erlang.term_to_binary()
    |> :erlang.md5()
    |> Base.encode16()
  end

  def strip_meta(code) do
    Macro.prewalk(code, fn
      {foo, _, bar} ->
        {foo, [], bar}

      other ->
        other
    end)
  end
end
