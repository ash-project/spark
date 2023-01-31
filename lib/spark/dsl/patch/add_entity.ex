defmodule Spark.Dsl.Patch.AddEntity do
  @moduledoc """
  Supply this when defining an extension to add entity builders to another extension's section.

  For example

  ```elixir
  @entity %Spark.Dsl.Entity{
    ...
  }

  @dsl_patch %Spark.Dsl.Patch.AddEntity{section_path: [:foo, :bar], entity: @entity}

  use Spark.Dsl.Extension, dsl_patches: [@dsl_patch]
  ```
  """
  @type t :: %__MODULE__{
          section_path: list(atom),
          entity: Spark.Dsl.Entity.t()
        }

  defstruct [:section_path, :entity]
end
