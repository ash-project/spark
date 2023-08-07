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
      Enum.reduce(entities_and_sections, {%{}, %{}}, fn element, acc ->
        {entities, sections} = acc

        case element do
          %Spark.Dsl.Entity{referenced_as: referenced_as} ->
            {Map.put(entities, referenced_as, element), sections}

          %Spark.Dsl.Section{referenced_as: referenced_as} ->
            {entities, Map.put(sections, referenced_as, element)}
        end
      end)

    entities = handle_entities(entities)

    sections =
      for {key, section} <- sections, into: %{} do
        {key, Map.put(section, :entities, Enum.map(section.entities, &Map.get(entities, &1)))}
      end

    sections = handle_sections(sections)
    for {_, section} <- sections, do: section
  end

  def handle_entity_children([], entities) do
    {[], entities}
  end

  def handle_entity_children(keyword_list, entities) do
    Enum.reduce(keyword_list, {[], entities}, fn {key, value}, {result_acc, entities} ->
      {result, entities} = handle_entity_node(value, entities)
      {result_acc ++ [{key, result}], entities}
    end)
  end

  def handle_entity_node(entity, entities) do
    case entity do
      atom when is_atom(atom) ->
        e = Map.get(entities, atom)
        {result, entities} = handle_entity_children(Map.get(e, :entities), entities)
        e = Map.put(e, :entities, result)
        {e, Map.put(entities, e.referenced_as, e)}

      list when is_list(list) ->
        Enum.reduce(list, {[], entities}, fn element, {result_acc, entities} ->
          {result, entities} = handle_entity_node(element, entities)
          {result_acc ++ [result], entities}
        end)

      entity ->
        {result, entities} = handle_entity_children(Map.get(entity, :entities), entities)
        entity = Map.put(entity, :entities, result)
        {entity, Map.put(entities, entity.referenced_as, entity)}
    end
  end

  def handle_entities(entity_map) do
    Enum.reduce(entity_map, entity_map, fn {_key, value}, state ->
      {_, state} = handle_entity_node(value, state)
      state
    end)
  end

  def handle_section_children([], sections) do
    {[], sections}
  end

  def handle_section_children(list, sections) do
    Enum.reduce(list, {[], sections}, fn value, {result_acc, sections} ->
      {result, sections} = handle_section_node(value, sections)
      {result_acc ++ [result], sections}
    end)
  end

  def handle_section_node(section, sections) do
    case section do
      atom when is_atom(atom) ->
        e = Map.get(sections, atom)
        {result, sections} = handle_section_children(Map.get(e, :sections), sections)
        e = Map.put(e, :sections, result)
        {e, Map.put(sections, e.referenced_as, e)}

      section ->
        {result, sections} = handle_section_children(Map.get(section, :sections), sections)
        section = Map.put(section, :sections, result)
        {section, Map.put(sections, section.referenced_as, section)}
    end
  end

  def handle_sections(section_map) do
    Enum.reduce(section_map, section_map, fn {_key, value}, state ->
      {_, state} = handle_section_node(value, state)
      state
    end)
  end
end
