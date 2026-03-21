# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Dsl.Verifier do
  @moduledoc """
  A verifier validates DSL state after compilation without modifying it.

  Unlike transformers, verifiers run after the module is compiled, so referencing other
  modules (e.g. checking that a related resource exists) will not create compile-time
  dependencies between them.

  ## Usage

      defmodule MyApp.MyExtension.Verifiers.ValidateNames do
        use Spark.Dsl.Verifier

        def verify(dsl_state) do
          case Spark.Dsl.Verifier.get_option(dsl_state, [:my_section], :name) do
            nil -> {:error, Spark.Error.DslError.exception(message: "name is required")}
            _name -> :ok
          end
        end
      end

  ## Callback

  `verify/1` receives the DSL state and should return:

  - `:ok` - validation passed
  - `{:error, term}` - validation failed
  - `{:warn, warning | [warning]}` - validation passed with warnings

  ## Reading State

  This module delegates read-only functions from `Spark.Dsl.Transformer`:
  `get_entities/2`, `get_option/3`, `fetch_option/3`, `get_persisted/2`.
  """

  @type warning() :: String.t() | {String.t(), :erl_anno.anno()}

  @callback verify(map) ::
              :ok
              | {:error, term}
              | {:warn, warning() | list(warning())}

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
