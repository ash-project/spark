defmodule Spark.Dsl.Internal.InsertEntitesIntoSections do
  @moduledoc false
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  def transform(dsl) do
    e_and_s = dsl |> Transformer.get_entities([:top_level])

    {entities, sections} =
      Enum.reduce(e_and_s, {%{}, %{}}, fn e, acc ->
        {entities, sections} = acc

        case e do
          %Spark.Dsl.Entity{name: name} ->
            {Map.put(entities, name, e), sections}

          %Spark.Dsl.Section{name: name} ->
            {entities, Map.put(sections, name, e)}
        end
      end)

    sections =
      for {_, section} <- sections do
        Map.put(section, :entities, Enum.map(section.entities, &Map.get(entities, &1)))
      end

    {:ok, dsl |> put_in([[:top_level], :entities], sections)}
  end
end
