# SPDX-FileCopyrightText: 2026 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.GenericOptsDsl do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      @opts [owner: :generic_dsl]
      @before_compile Spark.Test.GenericOptsDsl
    end
  end

  defmacro __before_compile__(env) do
    opts = Module.get_attribute(env.module, :opts)

    quote do
      def generic_dsl_options, do: unquote(Macro.escape(opts))
    end
  end
end

defmodule Spark.Test.OptionAware do
  @moduledoc false

  use Spark.Dsl

  def handle_before_compile(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)

    quote do
      def configured_otp_app, do: unquote(otp_app)
    end
  end
end
