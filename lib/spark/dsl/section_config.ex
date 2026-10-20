# SPDX-FileCopyrightText: 2026 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Dsl.SectionConfig do
  @moduledoc """
  The configuration of one section in a DSL state, stored under the section path.

  The struct implements `Access`, so bracket reads such as `dsl_state[path][:opts]` keep
  working for code written against the earlier plain-map shape. Popping a field resets it
  to its default.
  """

  @behaviour Access

  defstruct section_anno: nil, entities: [], opts: [], opts_anno: []

  @type t :: %__MODULE__{
          section_anno: :erl_anno.anno() | nil,
          entities: list(),
          opts: Keyword.t(),
          opts_anno: Keyword.t(:erl_anno.anno() | nil)
        }

  @fields [:section_anno, :entities, :opts, :opts_anno]

  @impl Access
  def fetch(%__MODULE__{} = config, key) when key in @fields, do: Map.fetch(config, key)
  def fetch(%__MODULE__{}, _key), do: :error

  @impl Access
  def get_and_update(%__MODULE__{} = config, key, fun) when key in @fields do
    current = Map.fetch!(config, key)

    case fun.(current) do
      {get, update} -> {get, Map.put(config, key, update)}
      :pop -> pop(config, key)
    end
  end

  def get_and_update(%__MODULE__{}, key, _fun) do
    raise KeyError, key: key, term: __MODULE__
  end

  @impl Access
  def pop(%__MODULE__{} = config, key) when key in @fields do
    {Map.fetch!(config, key), Map.put(config, key, Map.fetch!(%__MODULE__{}, key))}
  end

  def pop(%__MODULE__{} = config, _key), do: {nil, config}
end
