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

    entities = handle_entities(entities)

    for section <- sections do
      Map.put(section, :entities, Enum.map(section.entities, &Map.get(entities, &1)))
    end
  end

  def handle_entity_children([], entities) do
    {[], entities}
  end

  def handle_entity_children(keyword_list, entities) do
    Enum.reduce(keyword_list, {[], entities}, fn {key, value}, {result_acc, entities} ->
      {result, entities} = handle_entity_node(value, entities)
      {result_acc ++ [{key, [result]}], entities}
    end)
  end

  def handle_entity_node(entity, entities) do
    case entity do
      atom when is_atom(atom) ->
        e = Map.get(entities, atom)
        {result, entities} = handle_entity_children(Map.get(e, :entities), entities)
        e = Map.put(e, :entities, result)
        {e, Map.put(entities, e.name, e)}

      entity ->
        {result, entities} = handle_entity_children(Map.get(entity, :entities), entities)
        entity = Map.put(entity, :entities, result)
        {entity, Map.put(entities, entity.name, entity)}
    end
  end

  def handle_entities(entity_map) do
    Enum.reduce(entity_map, entity_map, fn {key, value}, state ->
      {_, state} = handle_entity_node(value, state)
      state
    end)
  end
end
