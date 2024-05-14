# Spark

Spark helps you build powerful and well documented DSLs that come with useful tooling out of the box. DSLs are declared using simple structs, and every DSL has the ability to be extended by the end user. Spark powers all of the DSLs in Ash Framework.

What you get for your DSL when you implement it with Spark:

- Extensibility. Anyone can write extensions for your DSL.
- Autocomplete and in-line documentation: An elixir_sense plugin that "Just Works" for any DSL implemented with Spark.
- Tools to generate documentation for your DSL automatically.
- A mix task to add every part of the DSL to the `locals_without_parens` of your library automatically.

This library has only recently been extracted out from Ash core, so there is still work to be done to document and test it in isolation. See the module documentation for the most up-to-date information.

## Dependency

`{:spark, "~> 2.1.22"}`


