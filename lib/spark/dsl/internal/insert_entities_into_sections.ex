defmodule Spark.Dsl.Internal.InsertEntitesIntoSections do
  @moduledoc false
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  def transform(dsl) do
    updated_dsl =
      Transformer.replace_entities(dsl, [:top_level], [], &substitute_entities_into_sections/1)

    {:ok, updated_dsl}
  end

  defp substitute_entities_into_sections(entities_and_sections) do
    {entities, sections} =
      Enum.reduce(entities_and_sections, {%{}, []}, fn element, acc ->
        {entities, sections} = acc

        case element do
          %Spark.Dsl.Entity{name: name} ->
            {Map.put(entities, name, element), sections}

          %Spark.Dsl.Section{} ->
            {entities, [element | sections]}
        end
      end)

    for section <- sections do
      Map.put(section, :entities, Enum.map(section.entities, &Map.get(entities, &1)))
    end
  end
end
