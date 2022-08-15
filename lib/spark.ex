defmodule Spark do
  @moduledoc """
  Documentation for `Spark`.
  """

  @doc "Returns true if the module implements the specified behavior"
  def implements_behaviour?(module, behaviour) do
    :attributes
    |> module.module_info()
    |> Enum.flat_map(fn
      {:behaviour, value} -> List.wrap(value)
      _ -> []
    end)
    |> Enum.any?(&(&1 == behaviour))
  rescue
    _ ->
      false
  end

  @doc "Returns the extensions a given DSL uses"
  def extensions(module) do
    Spark.Dsl.Extension.get_persisted(module, :extensions, [])
  end
end
