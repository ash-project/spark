# SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test do
  @moduledoc """
  ExUnit helpers for testing Spark DSL verifiers.

  Verifier errors raised inside Spark's `@after_verify` hook are converted to
  stderr warnings by the framework rather than propagated as exceptions, so
  the usual `assert_raise/2` testing pattern is unsuitable. This module
  exposes a structured alternative: register the test process as a collector,
  define DSL modules, and receive their `Spark.Error.DslError` values as data.

  ## Helpers

  - `dsl_errors/1` — runs a do-block and returns all collected verifier errors
    as `[{module, [%Spark.Error.DslError{}]}, ...]`. The error-side primitive.
  - `dsl_warnings/1` — runs a do-block and returns all collected verifier
    warnings as `[{module, [{message, location | nil}, ...]}, ...]`. The
    warning-side primitive.
  - `assert_dsl_error/2` — asserts that the do-block produces at least one
    error matching a given pattern and returns the matched error.
  - `assert_dsl_error/1` — like `/2` with a wildcard pattern: asserts at
    least one error of any kind.
  - `assert_dsl_warning/2` — asserts that the do-block produces at least
    one warning matching a given pattern and returns the matched payload.
  - `assert_dsl_warning/1` — like `/2` with a wildcard pattern: asserts at
    least one warning of any kind.
  - `refute_dsl_errors/1` — asserts that the do-block produces no errors at
    all. Use for happy-path tests.
  - `refute_dsl_warnings/1` — asserts that the do-block produces no
    warnings at all.

  ## Examples

      iex> Spark.Test.dsl_errors(do: :ok)
      []

      iex> Spark.Test.dsl_warnings(do: :ok)
      []

  See `dsl_errors/1`, `dsl_warnings/1`, `assert_dsl_error/2`, and
  `refute_dsl_errors/1` for full usage.

  ## Async safety

  All helpers in this module are safe to use from `async: true` ExUnit tests.
  The collection mechanism uses per-process state (`Process.put/2` and
  point-to-point `send/2`) and does not cross process boundaries.
  """

  @doc """
  Collects verifier errors from any Spark DSL modules defined inside the
  given do-block.

  Returns a list of `{module, [%Spark.Error.DslError{}]}` tuples in
  definition order. Modules that compile cleanly produce no entry. Stderr
  output emitted by verifiers (notably `{:warn, _}` returns) is suppressed
  during the call.

  ## Examples

  No DSL modules → empty list:

      errors = dsl_errors do
        :ok
      end
      # => []

  A failing DSL module → its errors:

      errors = dsl_errors do
        defmodule Elixir.MyExample do
          use MyApp.Validator

          fields do
            # invalid configuration here
          end
        end
      end

      [{MyExample, [%Spark.Error.DslError{} | _]}] = errors

  ## Module names defined inside the do-block

  Modules whose errors you intend to assert on must be defined with the
  fully-qualified `Elixir.SomeName` form. A bare alias inside the macro's
  callback is resolved against the surrounding test module's scope, while
  the same alias outside the call is resolved at the top level — without
  the `Elixir.` prefix the two atoms would not match.

  ## Cleanup

  The collector flag is restored to its prior value (or unset if there was
  no prior value) when the call returns or when the block raises. Stale
  messages are drained from the test process's mailbox so subsequent calls
  are not contaminated.

  See `Spark.Dsl.Verifier` for the verifier callback contract.
  """
  defmacro dsl_errors(do: block) do
    quote do
      previous = Process.put({Spark.Dsl, :test_collector}, self())

      try do
        ExUnit.CaptureIO.capture_io(:stderr, fn -> unquote(block) end)
        Spark.Test.__drain_errors__([])
      after
        case previous do
          nil -> Process.delete({Spark.Dsl, :test_collector})
          prev -> Process.put({Spark.Dsl, :test_collector}, prev)
        end

        Spark.Test.__drain_errors__([])
        Spark.Test.__drain_warnings__([])
      end
    end
  end

  @doc """
  Collects verifier warnings from any Spark DSL modules defined inside the
  given do-block.

  Returns a list of `{module, [{message, location | nil}, ...]}` tuples in
  definition order. Modules that compile cleanly produce no entry. The
  payloads are normalized: bare-string warnings become `{message, nil}`,
  tuple-form warnings preserve their `:erl_anno` location.

  Stderr output emitted from the block is suppressed during the call.

  ## Examples

  No DSL modules → empty list:

      warnings = dsl_warnings do
        :ok
      end
      # => []

  A DSL module with a warning verifier → its payloads:

      warnings = dsl_warnings do
        defmodule Elixir.MyExample do
          use MyApp.Validator
          # ... configuration that triggers the warning
        end
      end

      [{MyExample, [{message, _location} | _]}] = warnings

  See `dsl_errors/1` for the symmetric error-collection helper, and
  `Spark.Dsl.Verifier` for the verifier callback contract — including
  the shape of `{:warn, _}` returns.
  """
  defmacro dsl_warnings(do: block) do
    quote do
      previous = Process.put({Spark.Dsl, :test_collector}, self())

      try do
        ExUnit.CaptureIO.capture_io(:stderr, fn -> unquote(block) end)
        Spark.Test.__drain_warnings__([])
      after
        case previous do
          nil -> Process.delete({Spark.Dsl, :test_collector})
          prev -> Process.put({Spark.Dsl, :test_collector}, prev)
        end

        Spark.Test.__drain_errors__([])
        Spark.Test.__drain_warnings__([])
      end
    end
  end

  @doc """
  Asserts that the given do-block produces at least one verifier error and
  returns the first one.

  Equivalent to `assert_dsl_error/2` with a wildcard pattern: any
  `Spark.Error.DslError` matches. See `assert_dsl_error/2` for details on
  failure semantics, `refute_dsl_errors/1` for the inverse assertion, and
  `assert_dsl_warning/1` for the warning-side counterpart.
  """
  defmacro assert_dsl_error(do: block) do
    build_assert_error(quote(do: _), block)
  end

  @doc """
  Asserts that the given do-block produces at least one verifier error
  matching `pattern` and returns the matched error.

  `pattern` is matched against each `Spark.Error.DslError` in definition
  order via `match?/2`. The first match is returned. If no error matches,
  the test fails with a message that includes both the source form of the
  pattern and the inspected list of all collected errors.

  ## Examples

      err =
        assert_dsl_error %Spark.Error.DslError{path: [:fields, :email]} do
          defmodule Elixir.MyExample do
            use MyApp.Validator
            # ... configuration that triggers the verifier
          end
        end

      assert err.message =~ "invalid email"

  See `dsl_errors/1` for the underlying collection mechanism, including the
  rules for module names defined inside the do-block.
  """
  defmacro assert_dsl_error(pattern, do: block) do
    build_assert_error(pattern, block)
  end

  @doc """
  Asserts that the given do-block produces at least one verifier warning and
  returns the first one.

  Equivalent to `assert_dsl_warning/2` with a wildcard pattern: any warning
  payload matches. See `assert_dsl_warning/2` for details on failure
  semantics, and `assert_dsl_error/1` for the error-side counterpart.
  """
  defmacro assert_dsl_warning(do: block) do
    build_assert_warning(quote(do: _), block)
  end

  @doc """
  Asserts that the given do-block produces at least one verifier warning
  matching `pattern` and returns the matched payload.

  Each warning payload is a `{message, location | nil}` tuple. `pattern` is
  matched against each payload in definition order via `match?/2`. The first
  match is returned. If no payload matches, the test fails with a message
  that includes both the source form of the pattern and the inspected list
  of all collected warnings.

  ## Examples

      {message, _location} =
        assert_dsl_warning {_, _} do
          defmodule Elixir.MyExample do
            use MyApp.Validator
            # ... configuration that triggers the warning
          end
        end

      assert message =~ "deprecated"

  See `dsl_warnings/1` for the underlying collection mechanism, including
  the normalization of bare-string warnings to `{message, nil}` tuples.
  """
  defmacro assert_dsl_warning(pattern, do: block) do
    build_assert_warning(pattern, block)
  end

  @doc """
  Asserts that the given do-block produces no verifier errors.

  Returns `:ok` on success. If any `Spark.Error.DslError` values are
  collected, the test fails with a message that includes the inspected
  `[{module, [errors]}]` list, so the offending modules and their errors
  are visible in the failure output.

  Use this for happy-path tests where you want to assert that a DSL
  definition compiles cleanly through all verifiers.

  ## Example

      test "valid configuration is accepted" do
        refute_dsl_errors do
          defmodule Elixir.MyExample do
            use MyApp.Validator
            # ... valid configuration
          end
        end
      end

  See `dsl_errors/1` if you need access to the full collected list (e.g.
  when asserting on multiple distinct errors at once), and
  `refute_dsl_warnings/1` for the warning-side counterpart.
  """
  defmacro refute_dsl_errors(do: block) do
    quote do
      case Spark.Test.dsl_errors(do: unquote(block)) do
        [] ->
          :ok

        collected ->
          ExUnit.Assertions.flunk("""
          Expected no Spark.Error.DslError values, got:

          #{inspect(collected, pretty: true)}
          """)
      end
    end
  end

  @doc """
  Asserts that the given do-block produces no verifier warnings.

  Returns `:ok` on success. If any warning payloads are collected, the test
  fails with a message that includes the inspected
  `[{module, [{message, location | nil}, ...]}]` list, so the offending
  modules and their warnings are visible in the failure output.

  Use this for happy-path tests where you want to assert that a DSL
  definition compiles cleanly through all warning-emitting verifiers.

  ## Example

      test "no deprecated options used" do
        refute_dsl_warnings do
          defmodule Elixir.MyExample do
            use MyApp.Validator
            # ... configuration that uses no deprecated options
          end
        end
      end

  See `dsl_warnings/1` if you need access to the full collected list,
  and `refute_dsl_errors/1` for the error-side counterpart.
  """
  defmacro refute_dsl_warnings(do: block) do
    quote do
      case Spark.Test.dsl_warnings(do: unquote(block)) do
        [] ->
          :ok

        collected ->
          ExUnit.Assertions.flunk("""
          Expected no verifier warnings, got:

          #{inspect(collected, pretty: true)}
          """)
      end
    end
  end

  @doc false
  def __drain_errors__(acc) do
    receive do
      {Spark.Dsl, :verifier_errors, mod, errs} -> __drain_errors__([{mod, errs} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  @doc false
  def __drain_warnings__(acc) do
    receive do
      {Spark.Dsl, :verifier_warnings, _mod, []} ->
        __drain_warnings__(acc)

      {Spark.Dsl, :verifier_warnings, mod, payloads} ->
        __drain_warnings__([{mod, payloads} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp build_assert_error(pattern, block) do
    pattern_source = Macro.to_string(pattern)

    quote do
      collected = Spark.Test.dsl_errors(do: unquote(block))
      all_errors = Enum.flat_map(collected, fn {_mod, errs} -> errs end)

      case Enum.find(all_errors, fn err -> match?(unquote(pattern), err) end) do
        nil ->
          ExUnit.Assertions.flunk("""
          Expected a Spark.Error.DslError matching:

              #{unquote(pattern_source)}

          Got:
          #{inspect(all_errors, pretty: true)}
          """)

        err ->
          err
      end
    end
  end

  defp build_assert_warning(pattern, block) do
    pattern_source = Macro.to_string(pattern)

    quote do
      collected = Spark.Test.dsl_warnings(do: unquote(block))
      all_warnings = Enum.flat_map(collected, fn {_mod, payloads} -> payloads end)

      case Enum.find(all_warnings, fn warn -> match?(unquote(pattern), warn) end) do
        nil ->
          ExUnit.Assertions.flunk("""
          Expected a verifier warning matching:

              #{unquote(pattern_source)}

          Got:
          #{inspect(all_warnings, pretty: true)}
          """)

        warn ->
          warn
      end
    end
  end
end
