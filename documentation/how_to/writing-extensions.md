<!--
SPDX-FileCopyrightText: 2020 Zach Daniel
SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs.contributors>

SPDX-License-Identifier: MIT
-->

# Writing Extensions

Writing extensions generally involves three main components.

## The DSL declaration

The DSL is declared as a series of `Spark.Dsl.Section`, which can contain `Spark.Dsl.Entity` and further `Spark.Dsl.Section` structs. See `Spark.Dsl.Section` and `Spark.Dsl.Entity` for more information.

If you want to build those structs programmatically, see [Building Extensions with the Builder API](build-extensions-with-builders.md).

## Compile-time processing: Transformers, Persisters, and Verifiers

Extensions can hook into compilation at two stages: during compilation (Transformers and Persisters) and after compilation (Verifiers). Within the compilation stage, all Transformers run before any Persisters.

The overall execution order is:

1. **Transformers** — run during compilation, in dependency order. Can read and modify any part of the DSL state.
2. **Persisters** — run during compilation, after all Transformers have completed. Should only write to the persisted data map.
3. **Verifiers** — run after the module is compiled. Read-only. Does not create compile-time dependencies between modules.

All three are declared as options to `use Spark.Dsl.Extension`:

```elixir
use Spark.Dsl.Extension,
  sections: [@my_section],
  transformers: [MyApp.Transformers.SetDefaults],
  persisters: [MyApp.Persisters.CacheComputedValues],
  verifiers: [MyApp.Verifiers.ValidateConfig]
```

## Transformers

Each transformer can declare other transformers it must go before or after using `before?/1` and `after?/1` callbacks, and is then given the opportunity to modify the entirety of the DSL state. This allows extensions to make rich modifications to the structure in question.

```elixir
defmodule MyApp.Transformers.SetDefaults do
  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    name = Spark.Dsl.Transformer.get_option(dsl_state, [:my_section], :name)
    dsl_state = Spark.Dsl.Transformer.persist(dsl_state, :name, name || :default)
    {:ok, dsl_state}
  end

  def after?(MyApp.Transformers.EarlierTransformer), do: true
  def after?(_), do: false
end
```

See `Spark.Dsl.Transformer` for the full list of helper functions and return values.

## Persisters

Persisters implement the same `Spark.Dsl.Transformer` behaviour as transformers — they use `use Spark.Dsl.Transformer` and define a `transform/1` callback. The differences are:

- They are listed under `persisters:` instead of `transformers:`
- They **always** run after all transformers have finished, regardless of any `before?`/`after?` declarations targeting transformers (those are silently ignored)
- By convention, they should **only** write to the persisted data map via `Spark.Dsl.Transformer.persist/3`, and should not mutate sections or entities

Persisters do support `before?`/`after?` ordering relative to **other persisters**.

Use persisters to precompute and cache derived values that need a complete, fully-transformed view of the DSL:

```elixir
defmodule MyApp.Persisters.CacheActionNames do
  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    action_names =
      dsl_state
      |> Spark.Dsl.Transformer.get_entities([:actions])
      |> Enum.map(& &1.name)

    {:ok, Spark.Dsl.Transformer.persist(dsl_state, :action_names, action_names)}
  end
end
```

Persisted values can be retrieved at runtime via `Spark.Dsl.Extension.get_persisted/3`.

## Verifiers

Verifiers validate DSL state after the module has been compiled. They are read-only — they cannot modify the DSL state, only return `:ok`, `{:error, term}`, or `{:warn, warning}`. Because verifiers run post-compilation, they can safely reference other modules without creating compile-time dependencies between them.

```elixir
defmodule MyApp.Verifiers.ValidateConfig do
  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    name = Spark.Dsl.Verifier.get_option(dsl_state, [:my_section], :name)

    if name do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         message: "name is required",
         path: [:my_section, :name],
         module: Spark.Dsl.Verifier.get_persisted(dsl_state, :module)
       )}
    end
  end
end
```

Prefer verifiers over transformers when you only need to validate — they run later, see the final state, and their post-compilation timing avoids circular compile-time dependencies when referencing other Spark-based modules.

See `Spark.Dsl.Verifier` for the full list of helper functions and return values.

## Introspection

Use functions in `Spark.Dsl.Extension` to retrieve the stored values from the DSL and expose them in a module. The convention is to place functions for something like `MyApp.MyExtension` in `MyApp.MyExtension.Info`. Using introspection functions like this allows for a richer introspection API (i.e not just getting and retrieving raw values), and it also allows us to add type specs and documentation, which is helpful when working generically. I.e `module_as_variable.table()` can't be known by dialyzer, whereas `Extension.table(module)` can be.

## Source Annotations

Spark automatically tracks source location information for all DSL elements. This enables better error messages, IDE integration, and debugging capabilities. See [Using Source Annotations](use-source-annotations.md) for details on accessing and using this information in your extensions.
