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
    schema: [
      name: [type: :atom, required: true],
      target: [type: :module, required: true],
      entities: [type: :keyword_list, required: false]
    ]
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
