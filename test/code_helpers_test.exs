# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule Spark.CodeHelpersTest do
  use ExUnit.Case

  import Spark.CodeHelpers

  test "it generates functions properly when `when` is used in a multi-clausal function" do
    {code, funs} =
      lift_functions(
        quote do
          fn
            %{context: %{error: error}} = changeset, _context when not is_nil(error) ->
              {:error, error}

            changeset, _context ->
              changeset
          end
        end,
        :key,
        __ENV__
      )

    {:module, module, _, _} =
      Module.create(
        Foo,
        quote do
          unquote(funs)

          def fun, do: unquote(code)
        end,
        Macro.Env.location(__ENV__)
      )

    assert :erlang.fun_info(module.fun())[:arity] == 2
  end
end
