defmodule CrossExtensionPatchTest do
  use ExUnit.Case

  defmodule Template do
    @moduledoc false
    defstruct name: nil, type: nil

    def input(name) do
      %__MODULE__{name: name, type: :input}
    end
  end

  defmodule Argument do
    @moduledoc false
    defstruct name: nil, value: nil

    def entity do
      %Spark.Dsl.Entity{
        name: :argument,
        args: [:name, :value],
        imports: [Template],
        target: __MODULE__,
        schema: [
          name: [type: :atom, required: true],
          value: [type: {:struct, Template}, required: true]
        ]
      }
    end
  end

  defmodule Step do
    @moduledoc false
    defstruct name: nil, steps: [], arguments: []

    def entity(name) do
      %Spark.Dsl.Entity{
        name: name,
        args: [:name],
        entities: [
          steps: [],
          arguments: [Argument.entity()]
        ],
        recursive_as: :steps,
        target: __MODULE__,
        schema: [
          name: [type: :atom, required: true]
        ]
      }
    end
  end

  defmodule Input do
    @moduledoc false
    defstruct name: nil

    def entity do
      %Spark.Dsl.Entity{
        name: :input,
        args: [:name],
        target: __MODULE__,
        schema: [
          name: [type: :atom, required: true]
        ]
      }
    end
  end

  defmodule ExtensionA do
    @moduledoc false
    use Spark.Dsl.Extension,
      sections: [
        %Spark.Dsl.Section{
          name: :base,
          top_level?: true,
          patchable?: true,
          entities: [Step.entity(:step_a), Input.entity()]
        }
      ]
  end

  defmodule ExtensionB do
    @moduledoc false
    use Spark.Dsl.Extension,
      dsl_patches: [
        %Spark.Dsl.Patch.AddEntity{section_path: [:base], entity: Step.entity(:step_b)}
      ]
  end

  defmodule Dsl do
    @moduledoc false
    use Spark.Dsl, default_extensions: [extensions: [ExtensionA, ExtensionB]]
  end

  test "non patched entities are recursive" do
    defmodule NonPatchedRecursiveEntity do
      @moduledoc false
      use Dsl

      step_a :outer do
        step_a(:inner)
      end
    end

    assert [%{name: :outer, steps: [%{name: :inner}]}] =
             NonPatchedRecursiveEntity
             |> Spark.Dsl.Extension.get_entities([:base])
  end

  test "patched entities are recursive" do
    defmodule PatchedRecursiveEntity do
      @moduledoc false
      use Dsl

      step_b :outer do
        step_b(:inner)
      end
    end

    assert [%{name: :outer, steps: [%{name: :inner}]}] =
             PatchedRecursiveEntity
             |> Spark.Dsl.Extension.get_entities([:base])
  end

  test "patched entities can recurse into non-patched entities" do
    defmodule CrossExtensionPatchedEntityRecursion do
      @moduledoc false
      use Dsl

      step_b :outer do
        step_a(:inner)
      end
    end

    assert [%{name: :outer, steps: [%{name: :inner}]}] =
             CrossExtensionPatchedEntityRecursion
             |> Spark.Dsl.Extension.get_entities([:base])
  end

  test "patched entities with non-conflicting imports" do
    defmodule NonConflictingImports do
      @moduledoc false
      use Dsl

      input(:fruit)

      step_a :a do
        argument(:arg, input(:fruit))
      end

      step_b :b do
        argument(:arg, input(:bun))
      end
    end

    [%{value: %Template{name: :fruit}}, %{value: %Template{name: :bun}}] =
      NonConflictingImports
      |> Spark.Dsl.Extension.get_entities([:base])
      |> Enum.filter(&is_struct(&1, Step))
      |> Enum.flat_map(& &1.arguments)
  end
end
