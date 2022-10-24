defmodule Spark.Dsl.Builder do
  @moduledoc """
  Utilities for building DSL objects programatically, generally used in transformers.
  """

  defmacro __using__(_) do
    quote do
      import Spark.Dsl.Builder
    end
  end

  @type result :: {:ok, Spark.Dsl.t()} | {:error, term()}

  defmacro defbuilder({func, _, [dsl_state | rest_args]}, do: body) do
    def_head? = Enum.any?(rest_args, &match?({:\\, _, _}, &1))
    rest_args_with_defaults = rest_args

    rest_args =
      Enum.map(rest_args, fn
        {:\\, _, [expr, _default]} ->
          expr

        other ->
          other
      end)

    quote generated: true,
          location: :keep,
          bind_quoted: [
            def_head?: def_head?,
            rest_args: Macro.escape(rest_args),
            rest_args_with_defaults: Macro.escape(rest_args_with_defaults),
            dsl_state: Macro.escape(dsl_state),
            func: Macro.escape(func),
            body: Macro.escape(body)
          ] do
      if def_head? do
        def unquote(func)(unquote(dsl_state), unquote_splicing(rest_args_with_defaults))
      end

      def unquote(func)({:ok, unquote(dsl_state)}, unquote_splicing(rest_args)) do
        case unquote(body) do
          {:ok, result} ->
            {:ok, result}

          {:error, error} ->
            {:error, error}
        end
      end

      def unquote(func)(
            {:error, error},
            unquote_splicing(
              Enum.map(rest_args, fn _ ->
                {:_, [], Elixir}
              end)
            )
          ) do
        {:error, error}
      end

      def unquote(func)(unquote(dsl_state), unquote_splicing(rest_args)) do
        case unquote(body) do
          {:ok, result} ->
            {:ok, result}

          {:error, error} ->
            {:error, error}
        end
      end
    end
  end
end
