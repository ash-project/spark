# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

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
  @type input :: {:ok, Spark.Dsl.t()} | {:error, term()} | Spark.Dsl.t()

  defmacro defbuilder(call, do: body) do
    define_builder(:def, call, body)
  end

  defmacro defbuilderp(call, do: body) do
    define_builder(:defp, call, body)
  end

  defp define_builder(kind, {func, _, [dsl_state | rest_args_with_defaults]}, body) do
    rest_args =
      Enum.map(rest_args_with_defaults, fn
        {:\\, _, [expr, _default]} ->
          expr

        other ->
          other
      end)

    ignored_args = Enum.map(rest_args, fn _ -> {:_, [], Elixir} end)

    head =
      if Enum.any?(rest_args_with_defaults, &match?({:\\, _, _}, &1)) do
        quote do
          unquote(kind)(
            unquote(func)(unquote(dsl_state), unquote_splicing(rest_args_with_defaults))
          )
        end
      end

    quote generated: true, location: :keep do
      unquote(head)

      unquote(kind)(unquote(func)({:ok, unquote(dsl_state)}, unquote_splicing(rest_args))) do
        unquote(wrap_builder_result(body))
      end

      unquote(kind)(unquote(func)({:error, error}, unquote_splicing(ignored_args))) do
        {:error, error}
      end

      unquote(kind)(unquote(func)(unquote(dsl_state), unquote_splicing(rest_args))) do
        unquote(wrap_builder_result(body))
      end
    end
  end

  defp wrap_builder_result(body) do
    quote generated: true do
      case unquote(body) do
        {:ok, result} ->
          {:ok, result}

        {:error, error} ->
          {:error, error}

        body ->
          {:ok, body}
      end
    end
  end

  @doc """
  Handles nested values that may be `{:ok, result}` or `{:error, term}`, returning any errors and unwrapping any ok values

  This allows users of builders to do things like:

  ```elixir
  dsl_state
  |> Ash.Resource.Builder.add_new_action(:update, :publish,
    changes: [
      Ash.Resource.Builder.build_action_change(
        Ash.Resource.Change.Builtins.set_attribute(:state, :published)
      )
    ]
  )
  ```

  If your builder function calls `handle_nested_builders/2` with their input before building the thing its building.
  """
  def handle_nested_builders(opts, nested) do
    Enum.reduce_while(nested, {:ok, opts}, fn nested, {:ok, opts} ->
      case Keyword.get(opts, nested) do
        nil ->
          {:cont, {:ok, opts}}

        values when is_list(values) ->
          Enum.reduce_while(values, {:ok, []}, fn
            {:ok, value}, {:ok, values} ->
              {:cont, {:ok, [value | values]}}

            {:error, error}, _ ->
              {:halt, {:error, error}}

            value, {:ok, values} ->
              {:cont, {:ok, [value | values]}}
          end)
          |> case do
            {:ok, values} -> {:cont, {:ok, Keyword.put(opts, nested, Enum.reverse(values))}}
            other -> other
          end

        {:ok, value} ->
          {:cont, {:ok, Keyword.put(opts, nested, value)}}

        {:error, error} ->
          {:halt, {:error, error}}

        _value ->
          {:cont, {:ok, opts}}
      end
    end)
  end
end
