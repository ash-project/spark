# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.CollectorFixture do
  @moduledoc false
  # Fixture DSL used to test the test-collector hook in
  # `Spark.Dsl.__verify_spark_dsl__/1`.
  #
  # Provides:
  #   * a `:fixture` section with a `:trigger_error` boolean option
  #   * a verifier that returns `{:error, _}` when `trigger_error: true`
  #   * an after-compile transformer that increments a process-dict counter
  #     under the key `{Spark.Test.CollectorFixture, :counter}`
  #
  # Tests use the counter to observe whether the after-compile transformer
  # ran; the transformer must NOT run when the verifier produced errors.

  defmodule Dsl do
    @moduledoc false

    @section %Spark.Dsl.Section{
      name: :fixture,
      schema: [
        trigger_error: [type: :boolean, default: false],
        trigger_warning: [
          type: {:in, [false, :bare, :tuple, :multi]},
          default: false
        ]
      ]
    }

    defmodule MaybeError do
      @moduledoc false
      use Spark.Dsl.Verifier

      def verify(dsl) do
        if Spark.Dsl.Verifier.get_option(dsl, [:fixture], :trigger_error) do
          {:error,
           Spark.Error.DslError.exception(
             message: "fixture error",
             path: [:fixture],
             module: Spark.Dsl.Verifier.get_persisted(dsl, :module)
           )}
        else
          :ok
        end
      end
    end

    defmodule MaybeWarning do
      @moduledoc false
      use Spark.Dsl.Verifier

      def verify(dsl) do
        case Spark.Dsl.Verifier.get_option(dsl, [:fixture], :trigger_warning) do
          false ->
            :ok

          :bare ->
            {:warn, "fixture warning"}

          :tuple ->
            loc = Spark.Dsl.Transformer.get_section_anno(dsl, [:fixture])
            {:warn, {"fixture warning with location", loc}}

          :multi ->
            loc = Spark.Dsl.Transformer.get_section_anno(dsl, [:fixture])
            {:warn, ["fixture warning a", {"fixture warning b", loc}]}
        end
      end
    end

    defmodule BumpCounter do
      @moduledoc false
      use Spark.Dsl.Transformer

      def after_compile?, do: true

      def transform(dsl) do
        key = {Spark.Test.CollectorFixture, :counter}
        Process.put(key, (Process.get(key) || 0) + 1)
        {:ok, dsl}
      end
    end

    use Spark.Dsl.Extension,
      sections: [@section],
      verifiers: [MaybeError, MaybeWarning],
      transformers: [BumpCounter]
  end

  use Spark.Dsl, default_extensions: [extensions: Dsl]
end
