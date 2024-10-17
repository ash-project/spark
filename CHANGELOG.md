# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v2.2.35](https://github.com/ash-project/spark/compare/v2.2.34...v2.2.35) (2024-10-17)




### Bug Fixes:

* generate DSL documentation without a colon in the file name

## [v2.2.34](https://github.com/ash-project/spark/compare/v2.2.33...v2.2.34) (2024-10-15)




### Improvements:

* more and better typespecs for `Spark.Options.Validator`

## [v2.2.33](https://github.com/ash-project/spark/compare/v2.2.32...v2.2.33) (2024-10-13)




### Bug Fixes:

* include optional arguments as entity builders in spark.formatter

## [v2.2.32](https://github.com/ash-project/spark/compare/v2.2.31...v2.2.32) (2024-10-07)




### Improvements:

* disable introspection section in cheatsheets if target module is not documented (#111)

## [v2.2.31](https://github.com/ash-project/spark/compare/v2.2.30...v2.2.31) (2024-09-27)




### Improvements:

* add :impl option type (#110)

## [v2.2.30](https://github.com/ash-project/spark/compare/v2.2.29...v2.2.30) (2024-09-24)




### Improvements:

* raise multiple DslErrors at once

## [v2.2.29](https://github.com/ash-project/spark/compare/v2.2.28...v2.2.29) (2024-09-15)




### Improvements:

* add `Spark.Igniter.find` for search a DSL and all fragments

## [v2.2.28](https://github.com/ash-project/spark/compare/v2.2.27...v2.2.28) (2024-09-14)




### Bug Fixes:

* support latest elixir_ls changes

### Improvements:

* support fragments when finding DSL options

## [v2.2.27](https://github.com/ash-project/spark/compare/v2.2.26...v2.2.27) (2024-09-12)




### Bug Fixes:

* properly display unknown vs required option for missing keys

## [v2.2.26](https://github.com/ash-project/spark/compare/v2.2.25...v2.2.26) (2024-09-10)




### Bug Fixes:

* undo change supporting non keyword lists in spark options

## [v2.2.25](https://github.com/ash-project/spark/compare/v2.2.24...v2.2.25) (2024-09-10)




### Improvements:

* `:spark_behaviour` does not need to require opts be a list

## [v2.2.24](https://github.com/ash-project/spark/compare/v2.2.23...v2.2.24) (2024-09-06)




### Bug Fixes:

* remove experimental module/function docs ð¤¦

* don't assume all atoms could be module names

### Improvements:

* Don't just all the values when there may be a large number of values. (#106)

## [v2.2.23](https://github.com/ash-project/spark/compare/v2.2.22...v2.2.23) (2024-08-29)




### Improvements:

* add `get_option` igniter tool

* add `take` option to `to_options`

## [v2.2.22](https://github.com/ash-project/spark/compare/v2.2.21...v2.2.22) (2024-08-20)




### Bug Fixes:

* Macro.escape persisted keys

* properly handle {:error, error} when validating opts

### Improvements:

* add `fetch_persisted`

* add options type to option validators

## [v2.2.21](https://github.com/ash-project/spark/compare/v2.2.20...v2.2.21) (2024-08-14)




### Bug Fixes:

* add `private?` to options spec, and fix incorrect error output

## [v2.2.20](https://github.com/ash-project/spark/compare/v2.2.19...v2.2.20) (2024-08-14)




### Bug Fixes:

* show proper list of known options

* validate schema at compile time

## [v2.2.19](https://github.com/ash-project/spark/compare/v2.2.18...v2.2.19) (2024-08-13)




### Bug Fixes:

* cast default values

## [v2.2.18](https://github.com/ash-project/spark/compare/v2.2.17...v2.2.18) (2024-08-13)




### Bug Fixes:

* proper validation error on unknown optiosn

### Improvements:

* show `| nil` in struct type when optional

## [v2.2.17](https://github.com/ash-project/spark/compare/v2.2.16...v2.2.17) (2024-08-13)




### Bug Fixes:

* handle schemas w/ duplicate keys

### Improvements:

* add `docs/1` to options validators

## [v2.2.16](https://github.com/ash-project/spark/compare/v2.2.15...v2.2.16) (2024-08-13)




### Bug Fixes:

* properly validate defaults

## [v2.2.15](https://github.com/ash-project/spark/compare/v2.2.14...v2.2.15) (2024-08-13)




### Improvements:

* support getting an options list back out

* add `to_options/1` to options validators

* store which keys were provided in option validators

## [v2.2.14](https://github.com/ash-project/spark/compare/v2.2.13...v2.2.14) (2024-08-13)




### Bug Fixes:

* small fixes/cleanups for optiosn validations

## [v2.2.13](https://github.com/ash-project/spark/compare/v2.2.12...v2.2.13) (2024-08-13)




### Improvements:

* support define_deprecated_access? to help migrating to options validators

## [v2.2.12](https://github.com/ash-project/spark/compare/v2.2.11...v2.2.12) (2024-08-13)




### Improvements:

* optimize options validations (some)

* introduce new `Spark.Options.Validator`

## [v2.2.11](https://github.com/ash-project/spark/compare/v2.2.10...v2.2.11) (2024-07-30)




### Bug Fixes:

* (maybe temporarily) disable parallel compilation to resolve compile time issues

* ensure that sections are a list in `prepend_to_section_order/3`

## [v2.2.10](https://github.com/ash-project/spark/compare/v2.2.9...v2.2.10) (2024-07-18)




### Improvements:

* add docs & specs, and `Spark.Igniter.has_extension/5`

## [v2.2.9](https://github.com/ash-project/spark/compare/v2.2.8...v2.2.9) (2024-07-17)




### Bug Fixes:

* hide hidden docs & auto_set_fields in options tables

## [v2.2.8](https://github.com/ash-project/spark/compare/v2.2.7...v2.2.8) (2024-07-15)




### Improvements:

* add `Spark.Igniter.prepend_to_section_order`

## [v2.2.7](https://github.com/ash-project/spark/compare/v2.2.6...v2.2.7) (2024-07-02)




### Improvements:

* leverage latest igniter changes, update igniter tooling

## [v2.2.6](https://github.com/ash-project/spark/compare/v2.2.5...v2.2.6) (2024-06-28)




### Improvements:

* simplify & optimize import conflict resolution

* optimize and make idiomatic the entity building macros

* more idiomatic and performant section body & entity option macros

* optimize and make idiomatic the section option setter

## [v2.2.5](https://github.com/ash-project/spark/compare/v2.2.4...v2.2.5) (2024-06-25)




### Improvements:

* allow `%__MODULE__{}` to be used in escaped functions

## [v2.2.4](https://github.com/ash-project/spark/compare/v2.2.3...v2.2.4) (2024-06-20)




### Improvements:

* support igniter 0.2.0

## [v2.2.3](https://github.com/ash-project/spark/compare/v2.2.2...v2.2.3) (2024-06-17)




### Bug Fixes:

* properly support optional arguments before required ones

## [v2.2.2](https://github.com/ash-project/spark/compare/v2.2.1...v2.2.2) (2024-06-17)




### Bug Fixes:

* support optional arguments at the beginning of args list

## [v2.2.1](https://github.com/ash-project/spark/compare/v2.2.0...v2.2.1) (2024-06-14)




### Improvements:

* update to latest igniter, sourceror

## [v2.2.0](https://github.com/ash-project/spark/compare/v2.1.24...v2.2.0) (2024-06-13)




### Features:

* `mix spark.install` (a.k.a `mix igniter.install spark`)

### Improvements:

* `Spark.Igniter`, utilities for patching Spark DSL files

* handle `nil` `module` in dsl error more gracefully

## [v2.1.24](https://github.com/ash-project/spark/compare/v2.1.23...v2.1.24) (2024-06-10)




### Bug Fixes:

* ensure that options modules from sections are unimported

* ensure that unimports for sections are properly scoped

* ensure atom before check compiled (#99)

## [v2.1.23](https://github.com/ash-project/spark/compare/v2.1.22...v2.1.23) (2024-06-07)




### Bug Fixes:

* ensure that we infer the proper arity from multi-clause functions with `when`

* make shortdoc for cheat sheats mix task shorter (#95)

### Improvements:

* Use term_to_iovec instead of term_to_binary (#97)

* Make opts merge silent when values are identical (#96)

* hide `env` from persisted output in compile time

## [v2.1.22](https://github.com/ash-project/spark/compare/v2.1.21...v2.1.22) (2024-05-14)




### Bug Fixes:

* fix `Spark.Options.validate_type` for `:fun` (#91)

### Improvements:

* fix elixir-ls plugin to match latest release

* add more typespec coverage (#89)

* Add more spark types to `type_to_spec` and `schema_to_spec`.

## [v2.1.21](https://github.com/ash-project/spark/compare/v2.1.20...v2.1.21) (2024-05-10)




### Bug Fixes:

* properly match on `fetch_opt` in  Spark.InfoGenerator (#90)

### Improvements:

* better handling around default values for dsl options in info generator (#88)

## [v2.1.20](https://github.com/ash-project/spark/compare/v2.1.19...v2.1.20) (2024-04-21)




### Bug Fixes:

* honor the `add_extensions` option for DSL extensions

## [v2.1.19](https://github.com/ash-project/spark/compare/v2.1.18...v2.1.19) (2024-04-21)




### Improvements:

* handle more errors in elixir_sense plugin

## [v2.1.18](https://github.com/ash-project/spark/compare/v2.1.17...v2.1.18) (2024-04-12)




### Improvements:

* solve for compile time dependency issues

## [v2.1.17](https://github.com/ash-project/spark/compare/v2.1.16...v2.1.17) (2024-04-11)




### Bug Fixes:

* don't order sections unless an explicit order is given

## [v2.1.16](https://github.com/ash-project/spark/compare/v2.1.15...v2.1.16) (2024-04-10)




### Bug Fixes:

* remove debug code

## [v2.1.15](https://github.com/ash-project/spark/compare/v2.1.14...v2.1.15) (2024-04-10)




### Bug Fixes:

* fix builtin function matching

## [v2.1.14](https://github.com/ash-project/spark/compare/v2.1.13...v2.1.14) (2024-04-10)




### Bug Fixes:

* properly autocomplete entity argument values

## [v2.1.13](https://github.com/ash-project/spark/compare/v2.1.12...v2.1.13) (2024-04-05)




### Bug Fixes:

* still nailing down the opts list shuffling to end behavior

## [v2.1.12](https://github.com/ash-project/spark/compare/v2.1.11...v2.1.12) (2024-04-05)




### Bug Fixes:

* don't put do blocks into option values

* `replace_entity` should not add an entity if none are present (#82)

### Improvements:

* allow overriding generated info functions

## [v2.1.11](https://github.com/ash-project/spark/compare/v2.1.10...v2.1.11) (2024-03-29)




### Bug Fixes:

* don't count `true` or `false` as `spark_function_behaviour`

## [v2.1.10](https://github.com/ash-project/spark/compare/v2.1.9...v2.1.10) (2024-03-29)




### Bug Fixes:

* don't shuffle opts to end when filling required arguments

## [v2.1.9](https://github.com/ash-project/spark/compare/v2.1.8...v2.1.9) (2024-03-28)




### Bug Fixes:

* `nil` is not a valid module for spark function behaviour

## [v2.1.8](https://github.com/ash-project/spark/compare/v2.1.7...v2.1.8) (2024-03-27)




### Improvements:

* fix warnings

## [v2.1.7](https://github.com/ash-project/spark/compare/v2.1.6...v2.1.7) (2024-03-27)




### Bug Fixes:

* properly use `Keyword.put` for section/entity options

## [v2.1.6](https://github.com/ash-project/spark/compare/v2.1.5...v2.1.6) (2024-03-26)




### Bug Fixes:

* use the entity key, not the name, for placing entities

## [v2.1.5](https://github.com/ash-project/spark/compare/v2.1.4...v2.1.5) (2024-03-26)




### Improvements:

* ensure offered completions are unique

* ensure completions are offered to piped in functions

## [v2.1.4](https://github.com/ash-project/spark/compare/v2.1.3...v2.1.4) (2024-03-25)




### Improvements:

* Add `{:protocol, module}` as a supported type. (#79)

## [v2.1.3](https://github.com/ash-project/spark/compare/v2.1.2...v2.1.3) (2024-03-20)




### Improvements:

* handle single arg entities as options

* capture stacktrace in dsl errors, reuse on raising

## [v2.1.2](https://github.com/ash-project/spark/compare/v2.1.1...v2.1.2) (2024-03-18)




### Bug Fixes:

* add back in support for `:struct` type

## [v2.1.1](https://github.com/ash-project/spark/compare/v2.1.0...v2.1.1) (2024-03-18)




### Improvements:

* better, more type aware autocompletion

* less crashing of elixir ls

## [v2.1.0](https://github.com/ash-project/spark/compare/v2.0.1...v2.1.0) (2024-03-15)




### Bug Fixes:

* add defaults to `Verifier` functions

* autocomplete properly when multiple scopes are on one line

* don't require that using module is compiled

### Improvements:

* autocomplete for macros as well

* autocomplete options to `use` a DSL

* support autocompleting function opts

## [v2.0.1](https://github.com/ash-project/spark/compare/v2.0.0...v2.0.1) (2024-02-26)




### Bug Fixes:

* handle `nil` values in `spark_function_behaviour`

## [v2.0.0](https://github.com/ash-project/spark/compare/v1.1.54...v2.0.0) (2024-02-23)
### Breaking Changes:

* vendor NimbleOptions in `Spark.Options`



### Bug Fixes:

* honour an entity's snippet when one is present. (#77)

* only import recursive entities from other extensions inside entities

* import entity builders from other extensions inside of entities

## [v1.1.54](https://github.com/ash-project/spark/compare/v1.1.53...v1.1.54) (2024-01-12)




### Bug Fixes:

* properly detect dsl links with ? and ! in them

* update Spark.Formatter to respect `extensions` list (#73)

* spec & doc type for `:quoted`

* correct typespec/sanitisation for :in and :one_of (#72)

* proper typespec for keyed nimble types (#70)

* keep subsection of target merged schema

### Improvements:

* working `doc_type` for nested schemas (#71)

## [v1.1.53](https://github.com/ash-project/spark/compare/v1.1.52...v1.1.53) (2023-12-16)




### Bug Fixes:

* properly type spec map types

## [v1.1.52](https://github.com/ash-project/spark/compare/v1.1.51...v1.1.52) (2023-12-13)




### Bug Fixes:

* don't use question marks in module names

* Ensure `\\` for default argument values are rendered correctly in generated guides (#68)

### Improvements:

* accept structs in info functions by default

## [v1.1.51](https://github.com/ash-project/spark/compare/v1.1.50...v1.1.51) (2023-11-14)




### Improvements:

* ensure struct references are compiled

## [v1.1.50](https://github.com/ash-project/spark/compare/v1.1.49...v1.1.50) (2023-10-25)




### Bug Fixes:

* fix alias usage regression

### Improvements:

* change `:wrap_list` doc to `x | list(x)` (#60)

## [v1.1.49](https://github.com/ash-project/spark/compare/v1.1.48...v1.1.49) (2023-10-25)




### Bug Fixes:

* properly mark all aliases as used

* only optimize spark dsl config's with list paths

### Improvements:

* `persisters` are unordered transformers always run at the end

## [v1.1.48](https://github.com/ash-project/spark/compare/v1.1.47...v1.1.48) (2023-10-18)




### Improvements:

* optimize entity & option fetching

## [v1.1.47](https://github.com/ash-project/spark/compare/v1.1.46...v1.1.47) (2023-10-17)




### Improvements:

* optimize access to persisted data

* better error message on bad transformer

## [v1.1.46](https://github.com/ash-project/spark/compare/v1.1.45...v1.1.46) (2023-10-11)




### Bug Fixes:

* properly handle fragments after spark_dsl_config is set

* properly derive dsl state from source of truth in set_state

## [v1.1.45](https://github.com/ash-project/spark/compare/v1.1.44...v1.1.45) (2023-10-11)




### Bug Fixes:

* run transformers *after* handling fragments

## [v1.1.44](https://github.com/ash-project/spark/compare/v1.1.43...v1.1.44) (2023-10-11)




### Bug Fixes:

* properly set anchor links in cheat sheets

## [v1.1.43](https://github.com/ash-project/spark/compare/v1.1.42...v1.1.43) (2023-10-09)




### Bug Fixes:

* fix spark.formatter plugin not removing all parens

## [v1.1.42](https://github.com/ash-project/spark/compare/v1.1.41...v1.1.42) (2023-10-08)




### Improvements:

* markdown -> html for cheat_sheets

## [v1.1.41](https://github.com/ash-project/spark/compare/v1.1.40...v1.1.41) (2023-10-02)




### Bug Fixes:

* trim cheat_sheets before checking

* support nested types in `:keyword_list` and `:map` nimble types. (#62)

## [v1.1.40](https://github.com/ash-project/spark/compare/v1.1.39...v1.1.40) (2023-09-27)




### Improvements:

* add `mix spark.replace_doc_links`

* clean up cheat sheets & various type improvements

## [v1.1.39](https://github.com/ash-project/spark/compare/v1.1.38...v1.1.39) (2023-09-16)




### Bug Fixes:

* handle empty string case in cheat_sheets

## [v1.1.38](https://github.com/ash-project/spark/compare/v1.1.37...v1.1.38) (2023-09-16)




### Bug Fixes:

* allow empty extensions in spark.cheat_sheets

## [v1.1.37](https://github.com/ash-project/spark/compare/v1.1.36...v1.1.37) (2023-09-16)




### Improvements:

* `inspect_if` adds backticks for better docs

* better display for nested DSLs in cheat sheets

## [v1.1.36](https://github.com/ash-project/spark/compare/v1.1.35...v1.1.36) (2023-09-15)




### Improvements:

* include section descriptions

## [v1.1.35](https://github.com/ash-project/spark/compare/v1.1.34...v1.1.35) (2023-09-15)




### Bug Fixes:

* properly show entity argument examples

## [v1.1.34](https://github.com/ash-project/spark/compare/v1.1.33...v1.1.34) (2023-09-14)




### Improvements:

* add `--check` to `spark.cheat_sheets`

## [v1.1.33](https://github.com/ash-project/spark/compare/v1.1.32...v1.1.33) (2023-09-14)




### Improvements:

* don't show examples if there aren't any

## [v1.1.32](https://github.com/ash-project/spark/compare/v1.1.31...v1.1.32) (2023-09-14)




### Bug Fixes:

* don't remove DSL directory immediately after generating

## [v1.1.31](https://github.com/ash-project/spark/compare/v1.1.30...v1.1.31) (2023-09-14)




### Improvements:

* remove dsl cheat sheets after building

## [v1.1.30](https://github.com/ash-project/spark/compare/v1.1.29...v1.1.30) (2023-09-14)




### Improvements:

* more cheat sheet improvements

## [v1.1.29](https://github.com/ash-project/spark/compare/v1.1.28...v1.1.29) (2023-09-14)




### Improvements:

* show tags in cheat sheets

## [v1.1.28](https://github.com/ash-project/spark/compare/v1.1.27...v1.1.28) (2023-09-14)




### Improvements:

* better cheat sheet formatting & docs

## [v1.1.27](https://github.com/ash-project/spark/compare/v1.1.26...v1.1.27) (2023-09-14)




### Bug Fixes:

* properly unimport other extension top level sections

* only do top level unimports on second level paths

* handle more unimports of top level entities

* recusively sanitize keyword and map types. (#59)

* OptionsHelpers: Some nimble options types can have nested schemas. (#58)

### Improvements:

* better formatted cheat sheets

* add initial cheat sheet generators

## [v1.1.26](https://github.com/ash-project/spark/compare/v1.1.25...v1.1.26) (2023-09-11)




### Bug Fixes:

* recusively sanitize keyword and map types. (#59)

* OptionsHelpers: Some nimble options types can have nested schemas. (#58)

## [v1.1.25](https://github.com/ash-project/spark/compare/v1.1.24...v1.1.25) (2023-09-01)




### Bug Fixes:

* support patching top level sections

## [v1.1.24](https://github.com/ash-project/spark/compare/v1.1.23...v1.1.24) (2023-08-30)




### Bug Fixes:

* don't inspect dsl map in info generator errors

* code highlight error (#56)

### Improvements:

* allow `Patch.AddEntity` if a same-target entity exists (#53)

## [v1.1.23](https://github.com/ash-project/spark/compare/v1.1.22...v1.1.23) (2023-08-17)




### Improvements:

* handle when clauses on anonymous functions

## [v1.1.22](https://github.com/ash-project/spark/compare/v1.1.21...v1.1.22) (2023-07-27)




### Improvements:

* fix lexical import error in DSL macros

## [v1.1.21](https://github.com/ash-project/spark/compare/v1.1.20...v1.1.21) (2023-07-22)




### Improvements:

* support `{:spark, _}` in typespec generators

## [v1.1.20](https://github.com/ash-project/spark/compare/v1.1.19...v1.1.20) (2023-07-13)




### Improvements:

* add `verify` callback

* Spark.Dsl.Extension: Add `add_extensions` option which allows an extension to invite its friends. (#49)

## [v1.1.19](https://github.com/ash-project/spark/compare/v1.1.18...v1.1.19) (2023-07-11)




### Bug Fixes:

* unimport other extensions when opening a section

* reimport all sections after opening one

* unimport entire extension, reimport only pertinent sections

* only unimport/reimport necessary sections

* unimport top level sections

## [v1.1.18](https://github.com/ash-project/spark/compare/v1.1.17...v1.1.18) (2023-06-22)




### Bug Fixes:

* handle entity uniqueness properly

### Improvements:

* `defbuilderp`

## [v1.1.17](https://github.com/ash-project/spark/compare/v1.1.16...v1.1.17) (2023-06-20)




### Bug Fixes:

* nested entity paths contain their section?

* handle two-deep recursive as nested entity unimports

* fix imports around recursive_as entitites

### Improvements:

* unimport top level sections from non-top-level sections

## [v1.1.16](https://github.com/ash-project/spark/compare/v1.1.15...v1.1.16) (2023-06-20)




### Bug Fixes:

* handle mixed lists of entities better

* incorrect identity logic in `Transformer.build_entity/4`. (#44)

* better typespec for keyword lists

* wrap_list type fix behavior

* Entity: don't ever use `Map.put/3` to set an entity's `__identifier__`. (#43)

## [v1.1.15](https://github.com/ash-project/spark/compare/v1.1.14...v1.1.15) (2023-06-07)




### Bug Fixes:

* don't explode for non-tuple argument values. (#42)

## [v1.1.14](https://github.com/ash-project/spark/compare/v1.1.13...v1.1.14) (2023-06-07)




### Bug Fixes:

* Spark.Dsl.Entity: Clobbering of optional arguments (#41)

## [v1.1.13](https://github.com/ash-project/spark/compare/v1.1.12...v1.1.13) (2023-05-30)




### Improvements:

* add `:fun` options type

## [v1.1.12](https://github.com/ash-project/spark/compare/v1.1.11...v1.1.12) (2023-05-30)




### Bug Fixes:

* swap `Exception.exception?` for `Kernel.is_exception` (#36)

* don't support args in entity builders

* don't support builders for args

### Improvements:

* add `singleton_entity_keys` option

* moderately more helpful error message when introspecting a non Spark module. (#35)

* remove doc index

## [v1.1.11](https://github.com/ash-project/spark/compare/v1.1.10...v1.1.11) (2023-05-10)




### Improvements:

* don't document functions generated by Spark.Dls (#34)

## [v1.1.10](https://github.com/ash-project/spark/compare/v1.1.9...v1.1.10) (2023-05-04)




### Bug Fixes:

* handle more cases where notifier is not an extension

## [v1.1.9](https://github.com/ash-project/spark/compare/v1.1.8...v1.1.9) (2023-05-04)




### Bug Fixes:

* handle extensions with no sections

## [v1.1.8](https://github.com/ash-project/spark/compare/v1.1.7...v1.1.8) (2023-05-03)




### Bug Fixes:

* better behavior with latest elixirls release

## [v1.1.7](https://github.com/ash-project/spark/compare/v1.1.6...v1.1.7) (2023-05-03)




### Bug Fixes:

* remove hardcoded line number

## [v1.1.6](https://github.com/ash-project/spark/compare/v1.1.5...v1.1.6) (2023-05-03)




### Bug Fixes:

* handle more anonymous function types in DSLs

## [v1.1.5](https://github.com/ash-project/spark/compare/v1.1.4...v1.1.5) (2023-05-01)




### Improvements:

* better error messages on exceptions in transformers

## [v1.1.4](https://github.com/ash-project/spark/compare/v1.1.3...v1.1.4) (2023-04-27)




### Improvements:

* require `__identifier__` field for identifiers

## [v1.1.3](https://github.com/ash-project/spark/compare/v1.1.2...v1.1.3) (2023-04-26)




### Improvements:

* `Transformer.async_compile/2`

## [v1.1.2](https://github.com/ash-project/spark/compare/v1.1.1...v1.1.2) (2023-04-24)




### Improvements:

* don't wrap wrap_list snippets by default

## [v1.1.1](https://github.com/ash-project/spark/compare/v1.1.0...v1.1.1) (2023-04-24)




### Improvements:

* better snippets, `:wrap_list` type

## [v1.1.0](https://github.com/ash-project/spark/compare/v1.0.9...v1.1.0) (2023-04-22)




### Features:

* top level DSLs!

### Improvements:

* give every dsl entity a unique identifier

* support top level sections in elixir_sense plugin

## [v1.0.9](https://github.com/ash-project/spark/compare/v1.0.8...v1.0.9) (2023-04-21)




### Bug Fixes:

* correct args spec in `Spark.Dsl.Entity.t`. (#31)

### Improvements:

* add identifier-based entity replacement

* add `imports` to extensions

## [v1.0.8](https://github.com/ash-project/spark/compare/v1.0.7...v1.0.8) (2023-04-11)




### Bug Fixes:

* fix keyword_list types and list types

## [v1.0.7](https://github.com/ash-project/spark/compare/v1.0.6...v1.0.7) (2023-04-08)




### Bug Fixes:

* fix nested section module prefix

* remove merge warning in a single DSL

## [v1.0.6](https://github.com/ash-project/spark/compare/v1.0.5...v1.0.6) (2023-04-06)




### Improvements:

* sanitize nested schemas

## [v1.0.5](https://github.com/ash-project/spark/compare/v1.0.4...v1.0.5) (2023-04-06)




### Bug Fixes:

* properly merge fragments with base DSL

## [v1.0.4](https://github.com/ash-project/spark/compare/v1.0.3...v1.0.4) (2023-04-05)




### Bug Fixes:

* don't rely on new elixir version function

### Improvements:

* properly set extension types, and prevent overwriting

## [v1.0.3](https://github.com/ash-project/spark/compare/v1.0.2...v1.0.3) (2023-04-05)




### Bug Fixes:

* nested entities not being correctly checked for uniqueness. (#28)

## [v1.0.2](https://github.com/ash-project/spark/compare/v1.0.1...v1.0.2) (2023-04-05)




### Improvements:

* fragments & identifiers

## [v1.0.1](https://github.com/ash-project/spark/compare/v1.0.0...v1.0.1) (2023-03-31)




### Bug Fixes:

* unimport recursive options everywhere

## [v1.0.0](https://github.com/ash-project/spark/compare/v0.4.12...v1.0.0) (2023-03-31)
### Breaking Changes:

* much better recursive DSL ergonomics



### Improvements:

* better async compiler task handling

## [v0.4.12](https://github.com/ash-project/spark/compare/v0.4.11...v0.4.12) (2023-03-25)




### Bug Fixes:

* Relax nimble_options dependency (#27)

## [v0.4.11](https://github.com/ash-project/spark/compare/v0.4.10...v0.4.11) (2023-03-23)




### Improvements:

* make code helpers public

## [v0.4.10](https://github.com/ash-project/spark/compare/v0.4.9...v0.4.10) (2023-03-23)




### Improvements:

* update to nimble_options 1.0

## [v0.4.9](https://github.com/ash-project/spark/compare/v0.4.8...v0.4.9) (2023-03-21)




### Bug Fixes:

* better typespec generation

## [v0.4.8](https://github.com/ash-project/spark/compare/v0.4.7...v0.4.8) (2023-03-20)




### Improvements:

* ad `{:literal_value, value}` type

## [v0.4.7](https://github.com/ash-project/spark/compare/v0.4.6...v0.4.7) (2023-03-02)




### Bug Fixes:

* properly match patched entities in formatter

## [v0.4.6](https://github.com/ash-project/spark/compare/v0.4.5...v0.4.6) (2023-03-02)




### Bug Fixes:

* properly get all entity/option builders for formatter

## [v0.4.5](https://github.com/ash-project/spark/compare/v0.4.4...v0.4.5) (2023-02-19)




### Improvements:

* Make generated __using__/1 overridable for Dsls. (#26)

## [v0.4.4](https://github.com/ash-project/spark/compare/v0.4.3...v0.4.4) (2023-02-14)




### Bug Fixes:

* more fixes for aliases

## [v0.4.3](https://github.com/ash-project/spark/compare/v0.4.2...v0.4.3) (2023-02-13)




### Improvements:

* fix unused alias warnings once and for all

## [v0.4.2](https://github.com/ash-project/spark/compare/v0.4.1...v0.4.2) (2023-02-13)




### Bug Fixes:

* don't add docs to `@moduledoc false` mods

### Improvements:

* evaluate `Transformer.eval` chunks in the order they're added. (#24)

## [v0.4.1](https://github.com/ash-project/spark/compare/v0.4.0...v0.4.1) (2023-02-08)




### Bug Fixes:

* Make sections explicitly patchable, improve info generator. (#23)

## [v0.4.0](https://github.com/ash-project/spark/compare/v0.3.12...v0.4.0) (2023-02-06)




### Features:

* InfoGenerator: extract from AshAuthentication. (#22)

## [v0.3.12](https://github.com/ash-project/spark/compare/v0.3.11...v0.3.12) (2023-02-05)




### Bug Fixes:

* spark.formatter properly split modules

## [v0.3.11](https://github.com/ash-project/spark/compare/v0.3.10...v0.3.11) (2023-02-05)




### Bug Fixes:

* `all_entity_builders/3` passing extensions as path

* properly use Spark.Dsl behaviour

## [v0.3.10](https://github.com/ash-project/spark/compare/v0.3.9...v0.3.10) (2023-02-05)




### Bug Fixes:

* don't use `Keyword.update!` when we don't know the key is there

### Improvements:

* support DSL modules having an explain callback

* support adding entities via dsl patches

## [v0.3.9](https://github.com/ash-project/spark/compare/v0.3.8...v0.3.9) (2023-01-30)




### Bug Fixes:

* CodeHelpers: don't generate duplicate functions. (#20)

## [v0.3.8](https://github.com/ash-project/spark/compare/v0.3.7...v0.3.8) (2023-01-27)




### Bug Fixes:

* Support multiple function clauses in anonymous functions (#18)

* Entity.t: included `nil` option in typespecs where a field could be left default. (#17)

### Improvements:

* compile modules async for much faster compilation

* speed up compilation by defining DSL modules in parallel

## [v0.3.7](https://github.com/ash-project/spark/compare/v0.3.6...v0.3.7) (2023-01-19)




### Improvements:

* don't suggest do/end blocks for entities

## [v0.3.6](https://github.com/ash-project/spark/compare/v0.3.5...v0.3.6) (2023-01-18)




### Bug Fixes:

* remove variable scope when stripping metadata

### Improvements:

* update to new docs patterns

* centralize anonymous function handling code

* add `:quoted` type

## [v0.3.5](https://github.com/ash-project/spark/compare/v0.3.4...v0.3.5) (2023-01-12)




### Bug Fixes:

* exclude all metadata from code identifier

## [v0.3.4](https://github.com/ash-project/spark/compare/v0.3.3...v0.3.4) (2023-01-09)




### Bug Fixes:

* properly ensure options list is pushed to the end

* don't remove incorrect opts, broken in last commit

* properly handle optional keyword list/do blocks with optional args

## [v0.3.3](https://github.com/ash-project/spark/compare/v0.3.2...v0.3.3) (2023-01-06)




### Improvements:

* support functions in entity args better

## [v0.3.2](https://github.com/ash-project/spark/compare/v0.3.1...v0.3.2) (2022-12-22)




### Bug Fixes:

* support optional entity args in formatter

* run verifiers in after_compile hook in old versions

## Improvements:

* support `imports` option on entities

## [v0.3.1](https://github.com/ash-project/spark/compare/v0.3.0...v0.3.1) (2022-12-16)




### Bug Fixes:

* handle raised error in doc_index link replacements better

### Improvements:

* support optional entity arguments (ð)

## [v0.3.0](https://github.com/ash-project/spark/compare/v0.2.18...v0.3.0) (2022-12-14)




### Features:

* add verifiers

### Bug Fixes:

* ensure entities config exists for recursive entities

* properly traverse tuple subtypes

### Improvements:

* allow regexes in code modules

* add the file to the persisted state

* add `module` type

## [v0.2.18](https://github.com/ash-project/spark/compare/v0.2.17...v0.2.18) (2022-12-07)




### Bug Fixes:

* fix modules typespec

* typespecs: fix incorrect typespec for `Spark.Dsl.Entity.t` (#14)

### Improvements:

* update to latest nimble options

## [v0.2.17](https://github.com/ash-project/spark/compare/v0.2.16...v0.2.17) (2022-12-02)




### Improvements:

* more anonymous function type support

## [v0.2.16](https://github.com/ash-project/spark/compare/v0.2.15...v0.2.16) (2022-12-02)




### Improvements:

* support partial captures in functions

* leave unordered code where it is when sorting DSL sections

## [v0.2.15](https://github.com/ash-project/spark/compare/v0.2.14...v0.2.15) (2022-12-01)




### Bug Fixes:

* properly avoid unquoting functions out of context

## [v0.2.14](https://github.com/ash-project/spark/compare/v0.2.13...v0.2.14) (2022-12-01)




### Improvements:

* various DSL utilities, like `fetch_opt` and `sparks/2`

## [v0.2.13](https://github.com/ash-project/spark/compare/v0.2.12...v0.2.13) (2022-11-30)




### Improvements:

* support `remove_parens?` option for `Spark.Formatter`

* Typespecs: add a `t` type for `Spark.Dsl.Extension`. (#12)

## [v0.2.12](https://github.com/ash-project/spark/compare/v0.2.11...v0.2.12) (2022-11-21)




### Bug Fixes:

* Incorrect typespecs. (#11)

## [v0.2.11](https://github.com/ash-project/spark/compare/v0.2.10...v0.2.11) (2022-11-19)




### Bug Fixes:

* properly handle `{:or, [{:spark_function_behaviour, ...}]}` types

* support anonymous functions in an `or` type

* don't cause unnecessary export dependency recompilation

### Improvements:

* Add typespecs for `Spark.Dsl.Entity` and `Spark.Dsl.Section`. (#10)

## [v0.2.10](https://github.com/ash-project/spark/compare/v0.2.9...v0.2.10) (2022-11-15)




### Bug Fixes:

* add basename to guide typespec

## [v0.2.9](https://github.com/ash-project/spark/compare/v0.2.8...v0.2.9) (2022-11-15)




### Improvements:

* support explicitly ordering guides

## [v0.2.8](https://github.com/ash-project/spark/compare/v0.2.7...v0.2.8) (2022-11-03)




### Bug Fixes:

* properly link to libraries, and support `default_guide`

## [v0.2.7](https://github.com/ash-project/spark/compare/v0.2.6...v0.2.7) (2022-11-03)




### Improvements:

* support generic docs replacements renderer

## [v0.2.6](https://github.com/ash-project/spark/compare/v0.2.5...v0.2.6) (2022-10-31)




### Bug Fixes:

* add new `spark_function_behaviour` to elixir_sense plugin

### Improvements:

* support `{:or, ...}` option types

## [v0.2.5](https://github.com/ash-project/spark/compare/v0.2.4...v0.2.5) (2022-10-30)




### Bug Fixes:

* un-break recursive DSL entities

## [v0.2.4](https://github.com/ash-project/spark/compare/v0.2.3...v0.2.4) (2022-10-29)




### Improvements:

* support anonymous functions in the DSL

* remove necessity for `{:elixir_sense, ...}` to make the plugin work

## [v0.2.3](https://github.com/ash-project/spark/compare/v0.2.2...v0.2.3) (2022-10-28)




### Improvements:

* add `Builder.input()` type

## [v0.2.2](https://github.com/ash-project/spark/compare/v0.2.1...v0.2.2) (2022-10-28)




### Improvements:

* add `handle_nested_builders/2`

## [v0.2.1](https://github.com/ash-project/spark/compare/v0.2.0...v0.2.1) (2022-10-27)




### Bug Fixes:

* handle non tuple return in builder

## [v0.2.0](https://github.com/ash-project/spark/compare/v0.1.29...v0.2.0) (2022-10-24)




### Features:

* add `Spark.Dsl.Builder`

## [v0.1.29](https://github.com/ash-project/spark/compare/v0.1.28...v0.1.29) (2022-10-21)




### Improvements:

* add `{:struct, Struct}` option type

* DslError: Add type for `DslError` struct. (#4)

## [v0.1.28](https://github.com/ash-project/spark/compare/v0.1.27...v0.1.28) (2022-10-08)




### Bug Fixes:

* resolve issue w/ Code.eval_quoted

### Improvements:

* OptionsHelpers: Add typespecs for options helpers. (#3)

## [v0.1.27](https://github.com/ash-project/spark/compare/v0.1.26...v0.1.27) (2022-10-04)




### Bug Fixes:

* go back to fully hiding `no_require` modules

## [v0.1.26](https://github.com/ash-project/spark/compare/v0.1.25...v0.1.26) (2022-09-29)




### Improvements:

* add `mix_tasks/0` to `DocIndex`

## [v0.1.25](https://github.com/ash-project/spark/compare/v0.1.24...v0.1.25) (2022-09-20)




### Improvements:

* add `t()` type for DSL

## [v0.1.24](https://github.com/ash-project/spark/compare/v0.1.23...v0.1.24) (2022-09-20)




### Improvements:

* properly induce export dependency and still use aliases

## [v0.1.23](https://github.com/ash-project/spark/compare/v0.1.22...v0.1.23) (2022-09-20)




### Improvements:

* no dependencies hacked into export dependencies

## [v0.1.22](https://github.com/ash-project/spark/compare/v0.1.21...v0.1.22) (2022-09-20)




## [v0.1.21](https://github.com/ash-project/spark/compare/v0.1.20...v0.1.21) (2022-09-15)




### Bug Fixes:

* put back in fetching from module attribute if possible

## [v0.1.20](https://github.com/ash-project/spark/compare/v0.1.19...v0.1.20) (2022-09-15)




### Improvements:

* preliminary support for passing maps to introspection

* allow extensions to modify the module docs of an extension

## [v0.1.19](https://github.com/ash-project/spark/compare/v0.1.18...v0.1.19) (2022-08-31)




### Bug Fixes:

* revert ordering changes that appear to be causing errors

## [v0.1.18](https://github.com/ash-project/spark/compare/v0.1.17...v0.1.18) (2022-08-25)




### Bug Fixes:

* fix base resource pattern

* using type config in more places

* use configured type

### Improvements:

* add otp_app getter

## [v0.1.17](https://github.com/ash-project/spark/compare/v0.1.16...v0.1.17) (2022-08-23)




### Bug Fixes:

* don't create module docs for generated modules

## [v0.1.16](https://github.com/ash-project/spark/compare/v0.1.15...v0.1.16) (2022-08-23)




### Improvements:

* remove `default_guide/1`

## [v0.1.15](https://github.com/ash-project/spark/compare/v0.1.14...v0.1.15) (2022-08-19)




### Improvements:

* work on doc index

## [v0.1.14](https://github.com/ash-project/spark/compare/v0.1.13...v0.1.14) (2022-08-19)




### Improvements:

* add docs to hex package

## [v0.1.13](https://github.com/ash-project/spark/compare/v0.1.12...v0.1.13) (2022-08-19)




### Improvements:

* try out adding extra package metadata

## [v0.1.12](https://github.com/ash-project/spark/compare/v0.1.11...v0.1.12) (2022-08-18)




### Improvements:

* add default to get_option

* fix package files

## [v0.1.11](https://github.com/ash-project/spark/compare/v0.1.10...v0.1.11) (2022-08-18)




### Improvements:

* more documentation, tools for hex docs

## [v0.1.10](https://github.com/ash-project/spark/compare/v0.1.9...v0.1.10) (2022-08-18)




### Improvements:

* WIP on fixing the way we distribute doc files

## [v0.1.9](https://github.com/ash-project/spark/compare/v0.1.8...v0.1.9) (2022-08-17)




### Bug Fixes:

* properly ignore built in alias types

### Improvements:

* use libgraph to sort transformers

## [v0.1.8](https://github.com/ash-project/spark/compare/v0.1.7...v0.1.8) (2022-08-16)




### Improvements:

* don't provide the module to transformers

* update sourceror depednency

## [v0.1.7](https://github.com/ash-project/spark/compare/v0.1.6...v0.1.7) (2022-08-15)




### Improvements:

* add `spark.formatter.exs` (from ash)

## [v0.1.6](https://github.com/ash-project/spark/compare/v0.1.5...v0.1.6) (2022-08-14)




### Improvements:

* add formatter

## [v0.1.5](https://github.com/ash-project/spark/compare/v0.1.4...v0.1.5) (2022-08-14)




### Bug Fixes:

* properly use spark dsl error

## [v0.1.4](https://github.com/ash-project/spark/compare/v0.1.3...v0.1.4) (2022-08-14)




### Bug Fixes:

* add `Spark.Error.DslError`

## [v0.1.3](https://github.com/ash-project/spark/compare/v0.1.2...v0.1.3) (2022-08-14)




### Bug Fixes:

* properly handle `spark` types

## [v0.1.2](https://github.com/ash-project/spark/compare/v0.1.1...v0.1.2) (2022-08-14)




### Bug Fixes:

* validate spark types properly

## [v0.1.1](https://github.com/ash-project/spark/compare/v0.1.1...v0.1.1) (2022-08-14)



