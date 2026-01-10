# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Builder.Helpers do
  @moduledoc false

  @type validation :: (-> :ok | {:error, String.t()})

  @spec build(struct(), module(), [validation()]) :: {:ok, struct()} | {:error, String.t()}
  def build(builder, dsl_module, validations) when is_list(validations) do
    with :ok <- run_validations(validations) do
      attrs =
        builder
        |> Map.from_struct()
        |> Map.take(dsl_module.__field_names__())

      {:ok, struct!(dsl_module, attrs)}
    end
  end

  @spec build!(struct(), module(), String.t(), [validation()]) :: struct()
  def build!(builder, dsl_module, label, validations) when is_list(validations) do
    case build(builder, dsl_module, validations) do
      {:ok, built} -> built
      {:error, error} -> raise ArgumentError, "Invalid #{label}: #{error}"
    end
  end

  @spec resolve(term(), (term() -> term()), (term() -> boolean())) :: term()
  def resolve(value, build_fun, predicate)
      when is_function(build_fun, 1) and is_function(predicate, 1) do
    cond do
      is_function(value, 0) -> resolve(value.(), build_fun, predicate)
      predicate.(value) -> value
      true -> build_fun.(value)
    end
  end

  @spec resolve_list([term()], (term() -> term()), (term() -> boolean())) :: [term()]
  def resolve_list(values, build_fun, predicate)
      when is_list(values) and is_function(build_fun, 1) and is_function(predicate, 1) do
    Enum.map(values, &resolve(&1, build_fun, predicate))
  end

  defp run_validations([]), do: :ok

  defp run_validations([validation | rest]) when is_function(validation, 0) do
    with :ok <- validation.() do
      run_validations(rest)
    end
  end
end
