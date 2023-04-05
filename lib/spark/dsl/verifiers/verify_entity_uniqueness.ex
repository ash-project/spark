defmodule Spark.Dsl.Verifiers.VerifyEntityUniqueness do
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    dsl_state
    |> Verifier.get_persisted(:extensions)
    |> Enum.each(fn extension ->
      extension.sections
      |> Enum.each(fn section ->
        verify_entity_uniqueness(module, section, dsl_state)
      end)
    end)

    :ok
  end

  defp verify_entity_uniqueness(module, section, dsl_state, path \\ []) do
    section_path = path ++ [section.name]

    section.entities
    |> Enum.filter(& &1.identifier)
    |> Enum.each(fn entity ->
      do_verify_entity_uniqueness(module, entity, section_path, dsl_state)
    end)

    Enum.each(section.sections, fn section ->
      verify_entity_uniqueness(module, section, dsl_state, section_path)
    end)

    section.entities
    |> Enum.each(fn entity ->
      entities_to_check = Verifier.get_entities(dsl_state, section_path)

      entity.entities
      |> Enum.flat_map(fn {key, nested_entities} ->
        Enum.map(nested_entities, &{key, &1})
      end)
      |> Enum.filter(fn {_, nested_entity} ->
        nested_entity.identifier
      end)
      |> Enum.each(fn {key, nested_entity} ->
        verify_nested_entity_uniqueness(
          module,
          nested_entity,
          section_path,
          entities_to_check ++ recursive_entities,
          [key],
          new_recursive_entities
        )
      end)
    end)
  end

  defp verify_nested_entity_uniqueness(
         module,
         nested_entity,
         section_path,
         entities_to_check,
         nested_entity_path,
         recursive_entities
       ) do
    unique_entities_or_error(
      entities_to_check,
      nested_entity.identifier,
      module,
      section_path ++ nested_entity_path
    )

    entities_to_check
    |> Enum.each(fn entity_to_check ->
      nested_entity.entities
      |> Enum.flat_map(fn {key, nested_entities} ->
        Enum.map(nested_entities, &{key, &1})
      end)
      |> Enum.filter(fn {_, nested_entity} ->
        nested_entity.identifier
      end)
      |> Enum.each(fn {key, nested_entity} ->
        nested_entities_to_check = entity_to_check |> Map.get(key) |> List.wrap()

        verify_nested_entity_uniqueness(
          module,
          nested_entity,
          section_path,
          nested_entities_to_check,
          nested_entity_path ++ [key],
          recursive_entities
        )
      end)
    end)
  end

  defp do_verify_entity_uniqueness(module, entity, section_path, dsl_state) do
    dsl_state
    |> Verifier.get_entities(section_path)
    |> unique_entities_or_error(entity.identifier, module, section_path)
  end

  defp unique_entities_or_error(entities_to_check, identifier, module, path) do
    entities_to_check
    |> Enum.frequencies_by(&{Map.get(&1, identifier), &1.__struct__})
    |> Enum.find_value(fn {key, value} ->
      if value > 1 do
        key
      end
    end)
    |> case do
      nil ->
        :ok

      {identifier, target} ->
        raise Spark.Error.DslError,
          module: module,
          path: path ++ [identifier],
          message: """
          Got duplicate #{inspect(target)}: #{identifier}
          """
    end
  end
end
