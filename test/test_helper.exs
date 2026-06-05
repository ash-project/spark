# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

# ElixirSense builds its module store from *loaded* modules (it filters with
# `function_exported?/2`, which does not autoload). A real language server has the
# project's modules loaded, but in the test VM they're loaded lazily on first use,
# so the ElixirSense plugin and the DSL/behaviour-impl modules it needs to discover
# (e.g. `Spark.ElixirSense.Plugin`, `ExampleContacter`) aren't found. Eagerly load
# all of this application's modules so suggestions are discovered as they would be
# in a running language server.
case :application.get_key(:spark, :modules) do
  {:ok, modules} -> Enum.each(modules, &Code.ensure_loaded/1)
  _ -> :ok
end

ExUnit.start()
