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
      {foo, _, bar} when is_atom(foo) and is_atom(bar) ->
        {foo, [], nil}

      {foo, _, bar} ->
        {foo, [], bar}

      other ->
        other
    end)
  end

  # sobelow_skip ["DOS.BinToAtom"]
  def lift_functions(arg_value, key, caller) do
    case arg_value do
      {:&, _, [{:/, _, [{{:., _, _}, _, _}, _]}]} = value ->
        {value, nil}

      {:&, context1, [{:/, context2, [{_, _, _}, arity]}]} = value
      when is_integer(arity) ->
        fn_args = Macro.generate_unique_arguments(arity, caller.module)

        fun_name = Spark.CodeHelpers.code_identifier(value)

        fun_name =
          :"#{key}_#{Spark.Dsl.Extension.monotonic_number({key, fun_name})}_generated_#{fun_name}"

        function =
          {:&, context1,
           [
             {:/, context2,
              [
                {{:., [], [{:__aliases__, [alias: false], [caller.module]}, fun_name]},
                 [no_parens: true], []},
                Enum.count(fn_args)
              ]}
           ]}

        {function,
         quote generated: true do
           @doc false
           def unquote(fun_name)(unquote_splicing(fn_args)) do
             unquote(value).(unquote_splicing(fn_args))
           end
         end}

      {:&, _, [{name, _, fn_args}]} = value when is_atom(name) ->
        fn_args =
          Macro.prewalk(fn_args, [], fn
            {:&, _, [v]} = ast, acc when is_integer(v) ->
              {ast, [v | acc]}

            ast, acc ->
              {ast, acc}
          end)
          |> elem(1)
          |> Enum.uniq()
          |> Enum.count()
          |> Macro.generate_unique_arguments(caller.module)

        fun_name = Spark.CodeHelpers.code_identifier(value)

        fun_name =
          :"#{key}_#{Spark.Dsl.Extension.monotonic_number({key, fun_name})}_generated_#{fun_name}"

        function =
          {:&, [],
           [
             {:/, [context: Elixir, imports: [{2, Kernel}]],
              [
                {{:., [], [{:__aliases__, [alias: false], [caller.module]}, fun_name]},
                 [no_parens: true], []},
                Enum.count(fn_args)
              ]}
           ]}

        {function,
         quote generated: true do
           @doc false
           def unquote(fun_name)(unquote_splicing(fn_args)) do
             unquote(value).(unquote_splicing(fn_args))
           end
         end}

      {:&, _,
       [
         {{:., _, [{:__aliases__, _, _aliases}, name]}, _, fn_args}
       ]} = value
      when is_atom(name) ->
        fn_args =
          Macro.prewalk(fn_args, [], fn
            {:&, _, [v]} = ast, acc when is_integer(v) ->
              {ast, [v | acc]}

            ast, acc ->
              {ast, acc}
          end)
          |> elem(1)
          |> Enum.uniq()
          |> Enum.count()
          |> Macro.generate_unique_arguments(caller.module)

        fun_name = Spark.CodeHelpers.code_identifier(value)

        fun_name =
          :"#{key}_#{Spark.Dsl.Extension.monotonic_number({key, fun_name})}_generated_#{fun_name}"

        function =
          {:&, [],
           [
             {:/, [context: Elixir, imports: [{2, Kernel}]],
              [
                {{:., [], [{:__aliases__, [alias: false], [caller.module]}, fun_name]},
                 [no_parens: true], []},
                Enum.count(fn_args)
              ]}
           ]}

        {function,
         quote generated: true do
           @doc false
           def unquote(fun_name)(unquote_splicing(fn_args)) do
             unquote(value).(unquote_splicing(fn_args))
           end
         end}

      {:fn, _, [{:->, _, [fn_args, body]}]} = quoted_fn when is_list(fn_args) ->
        fun_name = Spark.CodeHelpers.code_identifier(quoted_fn)

        fun_name =
          :"#{key}_#{Spark.Dsl.Extension.monotonic_number({key, fun_name})}_generated_#{fun_name}"

        function =
          {:&, [],
           [
             {:/, [context: Elixir, imports: [{2, Kernel}]],
              [
                {{:., [], [{:__aliases__, [alias: false], [caller.module]}, fun_name]},
                 [no_parens: true], []},
                Enum.count(fn_args)
              ]}
           ]}

        {function,
         quote generated: true do
           @doc false
           def unquote(fun_name)(unquote_splicing(fn_args)) do
             unquote(body)
           end
         end}

      value ->
        {value, nil}
    end
  end
end
