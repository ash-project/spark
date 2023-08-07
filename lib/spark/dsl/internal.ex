defmodule Spark.Dsl.Internal do
  @moduledoc false

  defmodule Schema do
    @moduledoc false
    defstruct [:fields]
  end

  defmodule Field do
    @moduledoc false
    defstruct [:name, :type, :required, doc: ""]
  end

  @field %Spark.Dsl.Entity{
    name: :field,
    target: Field,
    args: [:name],
    schema: [
      name: [type: :atom, required: true],
      type: [type: :any, required: true],
      required: [type: :boolean, required: true],
      doc: [type: :string, required: false]
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
      args: [type: :any, required: false],
      auto_set_fields: [type: :keyword_list, required: false],
      deprecations: [type: :any, required: false],
      describe: [type: :string, required: false],
      entities: [type: :keyword_list, required: false],
      examples: [type: :any, required: false],
      hide: [type: :any, required: false],
      identifier: [type: :any, required: false],
      imports: [type: :any, required: false],
      links: [type: :any, required: false],
      modules: [type: :any, required: false],
      name: [type: :atom, required: true],
      no_depend_modules: [type: :any, required: false],
      recursive_as: [type: :any, required: false],
      referenced_as: [type: :atom, required: false],
      singleton_entity_keys: [type: :any, required: false],
      snippet: [type: :any, required: false],
      target: [type: :module, required: true],
      transform: [type: :any, required: false]
    ],
    transform: {Spark.Dsl.Internal, :entity, []}
  }

  def entity(struct) do
    updated_struct =
      case struct.referenced_as do
        nil -> %{struct | referenced_as: struct.name}
        _ -> struct
      end

    {:ok, updated_struct}
  end

  @section %Spark.Dsl.Entity{
    name: :section,
    target: Spark.Dsl.Section,
    entities: [schema: [@schema]],
    singleton_entity_keys: [:schema],
    schema: [
      auto_set_fields: [type: :any, required: false],
      deprecations: [type: :any, required: false],
      describe: [type: :string, required: false],
      entities: [type: {:list, :atom}, required: false],
      examples: [type: :any, required: false],
      imports: [type: :any, required: false],
      links: [type: :any, required: false],
      modules: [type: :any, required: false],
      name: [type: :atom, required: true],
      no_depend_modules: [type: :any, required: false],
      patchable?: [type: :any, required: false],
      referenced_as: [type: :atom, required: false],
      sections: [type: {:list, :atom}, required: false],
      snippet: [type: :any, required: false],
      top_level?: [type: :boolean, required: false]
    ],
    transform: {Spark.Dsl.Internal, :section, []}
  }

  def section(struct) do
    updated_struct =
      case struct.referenced_as do
        nil -> %{struct | referenced_as: struct.name}
        _ -> struct
      end

    updated_struct =
      case struct.schema do
        nil -> %{updated_struct | schema: []}
        _ -> struct
      end

    {:ok, updated_struct}
  end

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
