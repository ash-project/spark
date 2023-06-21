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

defmodule Spark.Dsl.Internal do
  @moduledoc false

  defmodule Schema do
    @moduledoc false
    defstruct [:fields]
  end

  defmodule Field do
    @moduledoc false
    defstruct [:name, :type, :required]
  end

  @field %Spark.Dsl.Entity{
    name: :field,
    target: Field,
    args: [:name],
    schema: [
      name: [type: :atom, required: true],
      type: [type: :any, required: true],
      required: [type: :boolean, required: true]
    ],
    transform: {Spark.Dsl.Internal, :field, []}
  }

  def field(struct) do
    %{name: name} = struct
    options = struct |> Map.drop([:name]) |> Map.from_struct() |> Map.to_list()
    {:ok, {name, options}}
  end

  @schema %Spark.Dsl.Entity{
    name: :schema,
    target: Schema,
    entities: [fields: [@field]],
    transform: {Spark.Dsl.Internal, :schema, []}
  }

  def schema(struct) do
    %Schema{fields: fields} = struct
    {:ok, fields}
  end

  @entity %Spark.Dsl.Entity{
    name: :entity,
    target: Spark.Dsl.Entity,
    entities: [schema: [@schema]],
    singleton_entity_keys: [:schema],
    schema: [name: [type: :atom, required: true], target: [type: :module, required: true]]
  }

  @section %Spark.Dsl.Entity{
    name: :section,
    target: Spark.Dsl.Section,
    schema: [
      name: [type: :atom, required: true],
      entities: [type: {:list, :atom}, required: true]
    ]
  }

  @top_level %Spark.Dsl.Section{
    name: :top_level,
    entities: [
      @entity,
      @section
    ],
    top_level?: true
  }

  use Spark.Dsl.Extension,
    sections: [@top_level],
    transformers: [Spark.Dsl.Internal.InsertEntitesIntoSections]
end
