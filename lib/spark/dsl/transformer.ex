# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Dsl.Transformer do
  @moduledoc """
  A transformer manipulates and/or validates the entire DSL state of a module at compile time.

  Transformers run during compilation and can read, modify, and persist DSL state. They are the
  primary mechanism for setting defaults, building entities programmatically, caching computed
  values, and reshaping configuration before the module is finalized.

  ## Usage

      defmodule MyApp.MyExtension.Transformers.SetDefaults do
        use Spark.Dsl.Transformer

        def transform(dsl_state) do
          # Read entities and options
          actions = Spark.Dsl.Transformer.get_entities(dsl_state, [:actions])

          # Modify DSL state and return it
          dsl_state = Spark.Dsl.Transformer.persist(dsl_state, :action_count, length(actions))
          {:ok, dsl_state}
        end
      end

  ## Callbacks

  - `transform/1` - Receives the DSL state map. Return `{:ok, dsl_state}` to continue with
    modifications, `:ok` to continue without modifications, `{:error, term}` to halt with an
    error, `{:warn, dsl_state, warnings}` to continue with warnings, or `:halt` to silently
    stop processing further transformers.

  - `before?/1` - Return `true` if this transformer must run before the given transformer module.

  - `after?/1` - Return `true` if this transformer must run after the given transformer module.

  ## Reading vs. Modifying State

  Use the helper functions in this module rather than manipulating the DSL state map directly.
  For reading: `get_entities/2`, `get_option/3`, `fetch_option/3`, `get_persisted/2`.
  For writing: `add_entity/3`, `replace_entity/3`, `remove_entity/3`, `set_option/4`, `persist/3`.

  ## Transformers vs. Verifiers

  If you only need to validate state without modifying it, and you reference other modules
  (e.g. checking that a referenced module exists), use `Spark.Dsl.Verifier` instead.
  Verifiers run after compilation and do not create compile-time dependencies between modules.
  """

  @type warning() :: String.t() | {String.t(), :erl_anno.anno()}

  @callback transform(map) ::
              :ok
              | {:ok, map}
              | {:error, term}
              | {:warn, map, warning() | list(warning())}
              | :halt
  @callback before?(module) :: boolean
  @callback after?(module) :: boolean
  @callback after_compile?() :: boolean

  defmacro __using__(_) do
    quote generated: true do
      @behaviour Spark.Dsl.Transformer

      def before?(_), do: false
      def after?(_), do: false
      def after_compile?, do: false

      defoverridable before?: 1, after?: 1, after_compile?: 0
    end
  end

  @doc """
  Saves a value into the dsl config with the given key.

  This can be used to precompute some information and cache it onto the resource,
  or simply store a computed value. It can later be retrieved with `Spark.Dsl.Extension.get_persisted/3`.
  """
  def persist(dsl, key, value) do
    Map.update(dsl, :persist, %{key => value}, &Map.put(&1, key, value))
  end

  @doc """
  Runs the function in an async compiler.

  Use this for compiling new modules and having them compiled
  efficiently asynchronously.
  """
  def async_compile(dsl, fun) do
    task = Spark.Dsl.Extension.do_async_compile(fun)

    tasks = get_persisted(dsl, :spark_compile_tasks, [])
    persist(dsl, :spark_compile_tasks, [task | tasks])
  end

  @doc """
  Add a quoted expression to be evaluated in the DSL module's context.

  Use this *extremely sparingly*. It should almost never be necessary, unless building certain
  extensions that *require* the module in question to define a given function.

  What you likely want is either one of the DSL introspection functions, like `Spark.Dsl.Extension.get_entities/2`
  or `Spark.Dsl.Extension.get_opt/5)`. If you simply want to store a custom value that can be retrieved easily, or
  cache some precomputed information onto the resource, use `persist/3`.

  Provide the dsl state, bindings that should be unquote-able, and the quoted block
  to evaluate in the module. For example, if we wanted to support a `resource.primary_key()` function
  that would return the primary key (this is unnecessary, just an example), we might do this:

  ```elixir
  fields = the_primary_key_fields

  dsl_state =
    Spark.Dsl.Transformer.eval(
      dsl_state,
      [fields: fields],
      quote do
        def primary_key() do
          unquote(fields)
        end
      end
    )
  ```
  """
  def eval(dsl, bindings, block) do
    to_eval = {block, bindings}

    Map.update(
      dsl,
      :eval,
      [to_eval],
      &[to_eval | &1]
    )
  end

  @doc """
  Retrieves a value that was previously stored with `persist/3`.

  Returns `default` if the key has not been persisted.
  """
  def get_persisted(dsl, key, default \\ nil) do
    dsl
    |> Map.get(:persist, %{})
    |> Map.get(key, default)
  end

  @doc """
  Fetches a persisted value, returning `{:ok, value}` or `:error`.
  """
  def fetch_persisted(dsl, key) do
    dsl
    |> Map.get(:persist, %{})
    |> Map.fetch(key)
  end

  @doc """
  Same as `build_entity/4` but raises on error.
  """
  def build_entity!(extension, path, name, opts) do
    case build_entity(extension, path, name, opts) do
      {:ok, entity} ->
        entity

      {:error, error} ->
        if is_exception(error) do
          raise error
        else
          raise "Error building entity #{inspect(error)}"
        end
    end
  end

  @doc """
  Programmatically builds an entity struct defined in the given extension.

  `path` is the section path (e.g. `[:actions]`), `name` is the entity name (e.g. `:read`),
  and `opts` is a keyword list of options matching the entity's schema. The entity's schema
  validations and transforms are applied.

  Commonly used to add entities to DSL state in a transformer:

      {:ok, action} = Transformer.build_entity(Ash.Resource.Dsl, [:actions], :read, name: :read)
      dsl_state = Transformer.add_entity(dsl_state, [:actions], action)
  """
  def build_entity(extension, path, name, opts) do
    do_build_entity(extension.sections(), path, name, opts)
  end

  defp do_build_entity(sections, [section_name], name, opts) do
    section = Enum.find(sections, &(&1.name == section_name))
    entity = Enum.find(section.entities, &(&1.name == name))

    do_build(entity, opts)
  end

  defp do_build_entity(
         sections,
         [section_name, maybe_entity_name],
         maybe_nested_entity_name,
         opts
       ) do
    section = Enum.find(sections, &(&1.name == section_name))

    entity =
      if section do
        Enum.find(section.entities, &(&1.name == maybe_entity_name))
      end

    sub_entity =
      if entity do
        entity.entities
        |> Keyword.values()
        |> List.flatten()
        |> Enum.find(&(&1.name == maybe_nested_entity_name))
      end

    if sub_entity do
      do_build(sub_entity, opts)
    else
      do_build_entity(section.sections, [maybe_entity_name], maybe_nested_entity_name, opts)
    end
  end

  defp do_build_entity(sections, [section_name | rest], name, opts) do
    section = Enum.find(sections, &(&1.name == section_name))
    do_build_entity(section.sections, rest, name, opts)
  end

  defp do_build(entity, opts) do
    entity_names =
      entity.entities
      |> Kernel.||([])
      |> Keyword.keys()

    {entities, opts} = Keyword.split(opts, entity_names)

    {before_validate_auto, after_validate_auto} =
      Keyword.split(entity.auto_set_fields || [], Keyword.keys(entity.schema))

    with {:ok, opts} <-
           Spark.Options.validate(
             Keyword.merge(opts, before_validate_auto),
             entity.schema
           ),
         opts <- Keyword.merge(opts, after_validate_auto) do
      result = struct(struct(entity.target, opts), entities)

      case Spark.Dsl.Entity.transform(entity.transform, result) do
        {:ok, built} ->
          Spark.Dsl.Entity.maybe_apply_identifier(built, entity.identifier)

        other ->
          other
      end
    else
      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Adds an entity to the DSL state at the given section path.

  By default, entities are prepended. Pass `type: :append` to append instead.
  """
  def add_entity(dsl_state, path, entity, opts \\ []) do
    Map.update(dsl_state, path, %{entities: [entity], opts: []}, fn config ->
      Map.update(config, :entities, [entity], fn entities ->
        if (opts[:type] || :prepend) == :prepend do
          [entity | entities]
        else
          entities ++ [entity]
        end
      end)
    end)
  end

  @doc """
  Removes entities at the given path that match the filter function.

  The function receives each entity and should return `true` for entities to remove.
  """
  def remove_entity(dsl_state, path, func) do
    Map.update(dsl_state, path, %{entities: [], opts: []}, fn config ->
      Map.update(config, :entities, [], fn entities ->
        Enum.reject(entities, func)
      end)
    end)
  end

  @doc """
  Returns all entities at the given section path.
  """
  def get_entities(dsl_state, path) do
    dsl_state
    |> Map.get(path, %{entities: []})
    |> Map.get(:entities, [])
  end

  @doc """
  Fetches a DSL option, returning `{:ok, value}` or `:error`.
  """
  def fetch_option(dsl_state, path, option) do
    dsl_state
    |> Map.get(path, Spark.Dsl.Extension.default_section_config())
    |> Map.get(:opts)
    |> Kernel.||([])
    |> Keyword.fetch(option)
  end

  @doc """
  Returns the source location annotation for a section, useful for error reporting.
  """
  @spec get_section_anno(map, list(atom)) :: :erl_anno.anno() | nil
  def get_section_anno(dsl_state, path) do
    dsl_state
    |> Map.get(path, %{})
    |> Map.get(:section_anno)
  end

  @doc """
  Returns the source location annotation for a specific option, useful for error reporting.
  """
  @spec get_opt_anno(map, list(atom), atom) :: :erl_anno.anno() | nil
  def get_opt_anno(dsl_state, path, option) do
    dsl_state
    |> Map.get(path, Spark.Dsl.Extension.default_section_config())
    |> Map.get(:opts_anno, [])
    |> Keyword.get(option)
  end

  @doc """
  Gets a DSL option value at the given section path, returning `default` if not set.
  """
  def get_option(dsl_state, path, option, default \\ nil) do
    dsl_state
    |> Map.get(path, Spark.Dsl.Extension.default_section_config())
    |> Map.get(:opts)
    |> Kernel.||([])
    |> Keyword.get(option, default)
  end

  @doc """
  Sets a DSL option value at the given section path.
  """
  def set_option(dsl_state, path, option, value) do
    dsl_state
    |> Map.put_new(path, Spark.Dsl.Extension.default_section_config())
    |> Map.update!(path, fn existing_opts ->
      existing_opts
      |> Map.put_new(:opts, [])
      |> Map.put_new(:opts_anno, [])
      |> Map.update!(:opts, fn opts ->
        Keyword.put(opts, option, value)
      end)
    end)
  end

  @doc """
  Replaces an entity at the given path with `replacement`.

  By default, matches on struct type and `__identifier__`. Pass a custom `matcher`
  function to control which entity gets replaced.
  """
  def replace_entity(dsl_state, path, replacement, matcher \\ nil) do
    matcher =
      matcher ||
        fn record ->
          record.__struct__ == replacement.__struct__ and
            record.__identifier__ == replacement.__identifier__
        end

    Map.replace_lazy(dsl_state, path, fn config ->
      Map.replace_lazy(config, :entities, fn entities ->
        replace_match(entities, replacement, matcher)
      end)
    end)
  end

  defp replace_match(entities, replacement, matcher) do
    Enum.map(entities, fn entity ->
      if matcher.(entity) do
        replacement
      else
        entity
      end
    end)
  end

  @doc false
  def sort(transformers) do
    digraph = :digraph.new()

    transformers
    |> Enum.each(fn transformer ->
      :digraph.add_vertex(digraph, transformer)
    end)

    transformers
    |> Enum.each(fn left ->
      transformers
      |> Enum.each(fn right ->
        if left != right do
          left_before_right? = left.before?(right) || right.after?(left)
          left_after_right? = left.after?(right) || right.before?(left)

          cond do
            # This is annoying, but some modules have `def after?(_), do: true`
            # The idea being that they'd like to go after everything that isn't
            # explicitly after it. Same with `def before?(_), do: true`
            left_before_right? && left_after_right? ->
              :ok

            left_before_right? ->
              if right not in :digraph.out_neighbours(digraph, left) do
                :digraph.add_edge(digraph, left, right)
              end

            left_after_right? ->
              if left not in :digraph.out_neighbours(digraph, right) do
                :digraph.add_edge(digraph, right, left)
              end

            true ->
              :ok
          end
        end
      end)
    end)

    transformers = walk_rest(digraph, transformers)
    :digraph.delete(digraph)

    transformers
  end

  defp walk_rest(digraph, transformers, acc \\ []) do
    case :digraph.vertices(digraph) do
      [] ->
        Enum.reverse(acc)

      vertices ->
        case Enum.find(vertices, &(:digraph.in_neighbours(digraph, &1) == [])) do
          nil ->
            case Enum.find(vertices, &(:digraph.out_neighbours(digraph, &1) == [])) do
              nil ->
                vertex =
                  Enum.min_by(vertices, fn l ->
                    Enum.find_index(transformers, &(&1 == l))
                  end)

                :digraph.del_vertex(digraph, vertex)
                walk_rest(digraph, transformers, acc ++ [vertex])

              vertex ->
                :digraph.del_vertex(digraph, vertex)
                walk_rest(digraph, transformers, acc ++ [vertex])
            end

          vertex ->
            :digraph.del_vertex(digraph, vertex)
            walk_rest(digraph, transformers, [vertex | acc])
        end
    end
  end
end
