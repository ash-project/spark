defmodule Spark.Dsl.Interface.Placeholder do
  @moduledoc """
  A placeholder struct used in interface definitions to indicate values that
  must be provided by implementing resources.

  When an interface defines a value as `%Placeholder{}`, it means that value
  is required to be present in any resource that implements the interface.
  The interface validation will check that implementing resources provide
  actual values for all placeholder positions.
  """

  defstruct [:key, :type, :description]

  @type t :: %__MODULE__{
          key: atom() | nil,
          type: atom() | nil,
          description: String.t() | nil
        }

  @doc """
  Creates a new placeholder with optional metadata.

  ## Examples

      iex> Spark.Dsl.Interface.Placeholder.new()
      %Spark.Dsl.Interface.Placeholder{}

      iex> Spark.Dsl.Interface.Placeholder.new(:name, :string, "The resource name")
      %Spark.Dsl.Interface.Placeholder{key: :name, type: :string, description: "The resource name"}
  """
  def new(key \\ nil, type \\ nil, description \\ nil) do
    %__MODULE__{
      key: key,
      type: type,
      description: description
    }
  end

  @doc """
  Checks if a value is a placeholder.

  ## Examples

      iex> Spark.Dsl.Interface.Placeholder.placeholder?(%Spark.Dsl.Interface.Placeholder{})
      true

      iex> Spark.Dsl.Interface.Placeholder.placeholder?("not a placeholder")
      false
  """
  def placeholder?(%__MODULE__{}), do: true
  def placeholder?(_), do: false
end
