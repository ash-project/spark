<!--
SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>

SPDX-License-Identifier: MIT
-->

# Testing Spark Verifiers

Verifier errors raised inside Spark's `@after_verify` hook are caught by the
framework and emitted as stderr warnings instead of propagated as exceptions.
This keeps compilation flowing when a DSL is invalid, but it means the
natural ExUnit pattern — `assert_raise/2` — does not work.

`Spark.Test` provides ExUnit helpers that turn the captured errors and
warnings back into structured data your tests can pattern-match on.

## Quick reference

| Intent | Errors | Warnings |
|---|---|---|
| Collect everything as a list | `dsl_errors/1` | `dsl_warnings/1` |
| Assert at least one matches a pattern | `assert_dsl_error/2` (or `/1` for any) | `assert_dsl_warning/2` (or `/1` for any) |
| Assert nothing was produced | `refute_dsl_errors/1` | `refute_dsl_warnings/1` |

`import Spark.Test` makes all six available.

## Defining modules inside the helpers

This rule catches everyone. Inside the macro's anonymous-function body, a
bare alias like `BadPerson` resolves against the surrounding test module's
scope. Outside — where your `assert` patterns live — the same alias
resolves at the top level. They become different atoms, and your patterns
will never match.

Force top-level resolution with the explicit `Elixir.X` form:

```elixir
errors =
  dsl_errors do
    defmodule Elixir.BadPerson do  # <-- note the Elixir. prefix
      ...
    end
  end

assert [{BadPerson, _}] = errors    # <-- bare alias resolves to Elixir.BadPerson, matches
```

Always use the `Elixir.X` form for any module you intend to assert on.

## Testing a verifier that produces errors

Anything that returns `{:error, %Spark.Error.DslError{}}` from
`Spark.Dsl.Verifier.verify/1` — your own verifiers and Spark's built-ins
(`VerifyEntityUniqueness`, `VerifySectionSingletonEntities`).

### Match a specific error

`assert_dsl_error/2` is the most common shape. It takes a pattern, runs the
do-block, and returns the first matching error so you can do follow-up
assertions on it:

```elixir
defmodule MyApp.PersonValidatorTest do
  use ExUnit.Case, async: true

  import Spark.Test

  test "rejects an invalid email" do
    err =
      assert_dsl_error %Spark.Error.DslError{path: [:fields, :email]} do
        defmodule Elixir.BadPerson do
          use MyApp.PersonValidator

          fields do
            field :email, :string do
              check &String.contains?(&1, "@")
            end
          end
        end
      end

    assert err.message =~ "invalid email"
  end
end
```

The pattern is matched via `match?/2`, so any valid Elixir pattern works.
On no match the test fails with a message that includes the pattern source
and the inspected list of actual errors.

When the pattern doesn't matter, use the `/1` form:

```elixir
err =
  assert_dsl_error do
    defmodule Elixir.BadPerson do
      # ...
    end
  end
```

### Assert clean compilation

For happy-path tests where no error should be produced:

```elixir
test "valid configuration is accepted" do
  refute_dsl_errors do
    defmodule Elixir.GoodPerson do
      use MyApp.PersonValidator

      fields do
        field :email, :string
      end
    end
  end
end
```

Returns `:ok` on success. On failure the message lists the offending
modules and their errors.

### Work with the full collected list

Use `dsl_errors/1` directly when you need to compare error counts, assert
on multiple distinct errors at once, or otherwise inspect the full result.
The shape is `[{module, [%Spark.Error.DslError{}]}, ...]` in definition
order:

```elixir
errors =
  dsl_errors do
    defmodule Elixir.HasTwoIssues do
      # ...
    end
  end

assert [{HasTwoIssues, errors_list}] = errors
assert length(errors_list) == 2
```

## Testing a verifier that produces warnings

The same three helpers exist (`dsl_warnings/1`, `assert_dsl_warning/2,/1`,
`refute_dsl_warnings/1`) with one shape difference:

**Warnings are normalized to `{message, location | nil}` tuples**, not
`Spark.Error.DslError` structs. A bare-string warning `{:warn, "msg"}`
becomes `{"msg", nil}`; a tuple-form warning `{:warn, {"msg", anno}}`
preserves the location. Source annotations require `debug_info` to be
enabled for tests — see [Asserting on source
annotations](#asserting-on-source-annotations) below.

```elixir
test "deprecated option emits a warning" do
  {message, _location} =
    assert_dsl_warning {_, _} do
      defmodule Elixir.UsesDeprecatedOption do
        use MyApp.Validator

        fields do
          field :legacy_option, :string
        end
      end
    end

  assert message =~ "deprecated"
end
```

For literal-message matching put the string in the pattern:

```elixir
{_, _} =
  assert_dsl_warning {"legacy_option is deprecated", _} do
    # ...
  end
```

`refute_dsl_warnings/1` and `dsl_warnings/1` work identically to their
errors counterparts, just with the warning payload shape.

## What the helpers don't capture

- **`Spark.Warning.warn/3` called directly** — for example by
  `Spark.Options` for schema-level deprecation warnings, or by
  `Spark.Dsl.Extension.__after_verify__/1` for `__spark_metadata__`
  deprecation. These bypass the verifier-callback path. Use
  `capture_io(:stderr, ...)` to assert on them.
- **Transformer warnings** — `{:warn, dsl_state, warnings}` returns from
  `Spark.Dsl.Transformer.transform/1` flow through a separate code path
  and are not collected.

## Asserting on source annotations

Spark only captures `:erl_anno.anno()` when `debug_info` is enabled. To
enable it for runtime modules compiled inside the helpers, add the
following to your `mix.exs`:

```elixir
test_elixirc_options: [debug_info: true]
```

Without it, `location` in `{message, location}` payloads is `nil` even when
the verifier passes the anno correctly.

## Async safety

The helpers are safe in `async: true` ExUnit tests. The collection
mechanism uses per-process state (`Process.put/2`) and point-to-point
`send/2`; nothing crosses process boundaries.

One caveat: any `defmodule` defined inside a process you spawn yourself
won't be captured, because the spawned process has its own dictionary.
Either keep `defmodule` calls in the same process as the helper, or set
the collector flag explicitly inside the spawned process:

```elixir
parent = self()

Task.async(fn ->
  Process.put({Spark.Dsl, :test_collector}, parent)
  defmodule Elixir.SomeModule do
    # ...
  end
end)
|> Task.await()
```

## See also

- `Spark.Test` — the helper module
- `Spark.Dsl.Verifier` — the verifier callback contract
- `Spark.Error.DslError` — the error struct returned by the error helpers
