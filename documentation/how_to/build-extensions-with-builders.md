<!--
SPDX-FileCopyrightText: 2025 spark contributors <https://github.com/ash-project/spark/graphs.contributors>

SPDX-License-Identifier: MIT
-->

# Building Extensions with the Builder API

This guide shows how to use the builder modules to define a DSL extension
programmatically. This is useful when you want to generate similar DSLs,
share schema fragments, or keep DSL construction in code instead of raw structs.

## Example: notifications extension

Define a small DSL with a single `notifications` section and a `notification`
entity. The schema uses `Field.new/3` with `(name, type, opts)` for types, defaults, docs, and
nested keys.

### Inline approach

For simple extensions, inline the builders directly in the `use` statement:

```elixir
defmodule MyApp.Notifications.Notification do
  defstruct [:name, :type, :target, :metadata, :__identifier__, :__spark_metadata__]
end

defmodule MyApp.Notifications.Dsl do
  alias Spark.Builder.{Entity, Field, Section}

  use Spark.Dsl.Extension,
    sections: [
      Section.new(:notifications,
        describe: "Notification configuration",
        entities: [
          Entity.new(:notification, MyApp.Notifications.Notification,
            describe: "Defines a notification delivery",
            args: [:name, :type],
            schema: [
              Field.new(:name, :atom, required: true, doc: "Notification name"),
              Field.new(:type, {:one_of, [:email, :slack]},
                required: true,
                doc: "Notification type"
              ),
              Field.new(:target, :string, doc: "Delivery target"),
              Field.new(:metadata, :keyword_list,
                keys: [
                  priority: [type: :integer, default: 0, doc: "Priority level"]
                ],
                doc: "Optional metadata"
              )
            ],
            identifier: :name
          )
          |> Entity.build!()
        ]
      )
      |> Section.build!()
    ]

  use Spark.Dsl, default_extensions: [extensions: __MODULE__]
end
```

### Helper module approach

In more complex cases, consider extracting builders into a separate module. This keeps
the DSL module clean and makes builders reusable:

```elixir
defmodule MyApp.Notifications.Notification do
  defstruct [:name, :type, :target, :metadata, :__identifier__, :__spark_metadata__]
end

defmodule MyApp.Notifications.Dsl.Builder do
  alias Spark.Builder.{Entity, Field, Section}

  def notification_entity do
    Entity.new(:notification, MyApp.Notifications.Notification,
      describe: "Defines a notification delivery",
      args: [:name, :type],
      schema: [
        Field.new(:name, :atom, required: true, doc: "Notification name"),
        Field.new(:type, {:one_of, [:email, :slack]},
          required: true,
          doc: "Notification type"
        ),
        Field.new(:target, :string, doc: "Delivery target"),
        Field.new(:metadata, :keyword_list,
          keys: [
            priority: [type: :integer, default: 0, doc: "Priority level"]
          ],
          doc: "Optional metadata"
        )
      ],
      identifier: :name
    )
    |> Entity.build!()
  end

  def notifications_section do
    Section.new(:notifications,
      describe: "Notification configuration",
      entities: [notification_entity()]
    )
    |> Section.build!()
  end
end

defmodule MyApp.Notifications.Dsl do
  alias MyApp.Notifications.Dsl.Builder

  use Spark.Dsl.Extension, sections: [Builder.notifications_section()]
  use Spark.Dsl, default_extensions: [extensions: __MODULE__]
end
```

## Using the DSL

```elixir
defmodule MyApp.Config do
  use MyApp.Notifications.Dsl

  notifications do
    notification :ops, :email do
      target "ops@example.com"
      metadata priority: 1
    end
  end
end
```

## Introspection helpers

You can expose a small info module that wraps `Spark.Dsl.Extension` helpers.

```elixir
defmodule MyApp.Notifications.Info do
  def notifications(module) do
    Spark.Dsl.Extension.get_entities(module, [:notifications])
  end
end
```

## Notes

- Types are passed as atoms or tuples (for example `{:one_of, [:email, :slack]}`).
- Use `Field.new/3` with `(name, type, opts)` to set `:required`, `:default`, `:keys`, and docs.
- The builder modules are `Spark.Builder.Field`, `Spark.Builder.Entity`, and
  `Spark.Builder.Section`.
