defmodule Spark.Dsl.Verifier do
  @moduledoc """
  A verifier gets the dsl state and can return `:ok` or `:error`.

  In a verifier, you can reference and depend on other modules without causing compile time dependencies.
  """
  @callback verify(map) ::
              :ok
              | {:error, term}
              | {:warn, String.t() | list(String.t())}

  defmacro __using__(_) do
    quote generated: true do
      @behaviour Spark.Dsl.Verifier
    end
  end

  defdelegate get_persisted(dsl, key), to: Spark.Dsl.Transformer
  defdelegate get_persisted(dsl, key, default), to: Spark.Dsl.Transformer
  defdelegate get_option(dsl_state, path, option), to: Spark.Dsl.Transformer
  defdelegate get_option(dsl_state, path, option, default), to: Spark.Dsl.Transformer
  defdelegate fetch_option(dsl_state, path, option), to: Spark.Dsl.Transformer
  defdelegate get_entities(dsl_state, path), to: Spark.Dsl.Transformer
end
