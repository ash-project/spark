defmodule Spark.CodeHelpers do
  @moduledoc false

  @doc """
  Given a section of Elixir AST, generate a hash of the code to help with
  generating unique names.
  """
  @spec code_identifier(Macro.t()) :: binary
  def code_identifier(code) do
    code
    |> strip_meta()
    |> :erlang.term_to_binary()
    |> :erlang.md5()
    |> Base.encode16()
  end

  @doc false
  @spec strip_meta(Macro.t()) :: Macro.t()
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

  @doc """
  Lift anonymous and captured functions.

  Acts as an AST transformer to allow these kinds of functions to be added in
  the AST:

  In the case of captured functions, it ensures they are all captured remote
  functions (ie calls with both the module and function name present) - this
  often requires the definition of a new public function on the target module.

  In the case of anonymous functions, it converts them into a new public
  function on the module and returns a (remote) function capture much like that
  of above.
  """
  @spec lift_functions(Macro.t(), atom, Macro.Env.t()) :: Macro.t()
  # (Don't) lift functions of the `&Module.function/arity` format
  def lift_functions({:&, _, [{:/, _, [{{:., _, _}, _, _}, _]}]} = value, _key, _caller),
    do: {value, nil}

  # Lift functions of the `&function/arity` variety
  def lift_functions({:&, context1, [{:/, context2, [{_, _, _}, arity]}]} = value, key, caller)
      when is_integer(arity) do
    fn_args = Macro.generate_unique_arguments(arity, caller.module)
    fn_name = generate_unique_function_name(value, key)
    function = generate_captured_function_caller(fn_name, arity, caller, context1, context2)

    {function,
     quote generated: true do
       @doc false
       def unquote(fn_name)(unquote_splicing(fn_args)) do
         unquote(value).(unquote_splicing(fn_args))
       end
     end}
  end

  # Lift function of the `&function(&1, args)` variety
  def lift_functions({:&, _, [{name, _, fn_args}]} = value, key, caller) when is_atom(name) do
    fn_args = generate_captured_arguments(fn_args, caller)
    fn_name = generate_unique_function_name(value, key)
    function = generate_captured_function_caller(fn_name, fn_args, caller)

    {function,
     quote generated: true do
       @doc false
       def unquote(fn_name)(unquote_splicing(fn_args)) do
         unquote(value).(unquote_splicing(fn_args))
       end
     end}
  end

  # Lift functions of the `&Module.function(&1, args)` variety
  def lift_functions(
        {:&, _, [{{:., _, [{:__aliases__, _, _aliases}, name]}, _, fn_args}]} = value,
        key,
        caller
      )
      when is_atom(name) do
    fn_args = generate_captured_arguments(fn_args, caller)
    fn_name = generate_unique_function_name(value, key)
    function = generate_captured_function_caller(fn_name, fn_args, caller)

    {function,
     quote generated: true do
       @doc false
       def unquote(fn_name)(unquote_splicing(fn_args)) do
         unquote(value).(unquote_splicing(fn_args))
       end
     end}
  end

  # Lift anonymous functions with one or more clauses.
  def lift_functions(
        {:fn, _, [{:->, _, [fn_args, _body]} | _] = clauses} = quoted_fn,
        key,
        caller
      )
      when is_list(fn_args) do
    fn_name = generate_unique_function_name(quoted_fn, key)
    function = generate_captured_function_caller(fn_name, fn_args, caller)

    function_defs =
      for {:->, _, [args, body]} <- clauses do
        quote do
          def unquote(fn_name)(unquote_splicing(args)) do
            unquote(body)
          end
        end
      end

    {function,
     quote generated: true do
       @doc false
       unquote_splicing(function_defs)
     end}
  end

  # Ignore all other values.
  def lift_functions(value, _key, _caller), do: {value, nil}

  # sobelow_skip ["DOS.BinToAtom"]
  defp generate_unique_function_name(value, key) do
    fn_name = Spark.CodeHelpers.code_identifier(value)

    :"#{key}_#{Spark.Dsl.Extension.monotonic_number({key, fn_name})}_generated_#{fn_name}"
  end

  # Counts up all the arguments and generates new unique arguments for them.
  # Works around the caveat that each usage of a unique `&n` variable must only
  # be counted once.
  defp generate_captured_arguments(args, caller) do
    Macro.prewalk(args, [], fn
      {:&, _, [v]} = ast, acc when is_integer(v) ->
        {ast, [v | acc]}

      ast, acc ->
        {ast, acc}
    end)
    |> elem(1)
    |> Enum.uniq()
    |> Enum.count()
    |> Macro.generate_unique_arguments(caller.module)
  end

  # Generates the code for calling the target function as a function capture.
  defp generate_captured_function_caller(
         fn_name,
         arity,
         caller,
         context1 \\ [],
         context2 \\ [context: Elixir, imports: [{2, Kernel}]]
       )

  defp generate_captured_function_caller(fn_name, arity, caller, context1, context2)
       when is_integer(arity) do
    {:&, context1,
     [
       {:/, context2,
        [
          {{:., [], [{:__aliases__, [alias: false], [caller.module]}, fn_name]},
           [no_parens: true], []},
          arity
        ]}
     ]}
  end

  defp generate_captured_function_caller(fn_name, fn_args, caller, context1, context2),
    do:
      generate_captured_function_caller(
        fn_name,
        Enum.count(fn_args),
        caller,
        context1,
        context2
      )
end
