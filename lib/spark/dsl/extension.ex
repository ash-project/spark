defmodule Spark.Dsl.Extension do
  @moduledoc """
  An extension to the Spark DSL.

  This allows configuring custom DSL components, whose configurations
  can then be read back. This guide is still a work in progress, but should
  serve as a decent example of what is possible. Open issues on Github if you
  have any issues/something is unclear.

  The example at the bottom shows how you might build a (not very contextually
  relevant) DSL extension that would be used like so:

      defmodule MyApp.MyResource do
        use Ash.Resource,
          extensions: [MyApp.CarExtension]

        cars do
          car :mazda, "6", trim: :touring
          car :toyota, "corolla"
        end
      end

  The extension:

      defmodule MyApp.CarExtension do
        @car_schema [
          make: [
            type: :atom,
            required: true,
            doc: "The make of the car"
          ],
          model: [
            type: :atom,
            required: true,
            doc: "The model of the car"
          ],
          type: [
            type: :atom,
            required: true,
            doc: "The type of the car",
            default: :sedan
          ]
        ]

        @car %Spark.Dsl.Entity{
          name: :car,
          describe: "Adds a car",
          examples: [
            "car :mazda, \"6\""
          ],
          target: MyApp.Car,
          args: [:make, :model],
          schema: @car_schema
        }

        @cars %Spark.Dsl.Section{
          name: :cars, # The DSL constructor will be `cars`
          describe: \"\"\"
          Configure what cars are available.

          More, deeper explanation. Always have a short one liner explanation,
          an empty line, and then a longer explanation.
          \"\"\",
          entities: [
            @car # See `Spark.Dsl.Entity` docs
          ],
          schema: [
            default_manufacturer: [
              type: :atom,
              doc: "The default manufacturer"
            ]
          ]
        }

        use Spark.Dsl.Extension, sections: [@cars]
      end


  Often, we will need to do complex validation/validate based on the configuration
  of other resources. Due to the nature of building compile time DSLs, there are
  many restrictions around that process. To support these complex use cases, extensions
  can include `transformers` which can validate/transform the DSL state after all basic
  sections/entities have been created. See `Spark.Dsl.Transformer` for more information.
  Transformers are provided as an option to `use`, like so:

      use Spark.Dsl.Extension, sections: [@cars], transformers: [
        MyApp.Transformers.ValidateNoOverlappingMakesAndModels
      ]

  By default, the generated modules will have names like `__MODULE__.SectionName.EntityName`, and that could
  potentially conflict with modules you are defining, so you can specify the `module_prefix` option, which would allow
  you to prefix the modules with something like `__MODULE__.Dsl`, so that the module path generated might be something like
  `__MODULE__.Dsl.SectionName.EntityName`, and you could then have the entity struct be `__MODULE__.SectionName.EntityName`
  without conflicts.

  To expose the configuration of your DSL, define functions that use the
  helpers like `get_entities/2` and `get_opt/3`. For example:

      defmodule MyApp.Cars do
        def cars(resource) do
          Spark.Dsl.Extension.get_entities(resource, [:cars])
        end
      end

      MyApp.Cars.cars(MyResource)
      # [%MyApp.Car{...}, %MyApp.Car{...}]

  See the documentation for `Spark.Dsl.Section` and `Spark.Dsl.Entity` for more information
  """

  @type t :: module

  @callback sections() :: [Spark.Dsl.section()]
  @callback transformers() :: [module]
  @callback verifiers() :: [module]
  @callback explain(map) :: String.t() | nil

  @optional_callbacks explain: 1

  defp dsl!(resource) do
    resource.spark_dsl_config()
  rescue
    _ in [UndefinedFunctionError, ArgumentError] ->
      try do
        Module.get_attribute(resource, :spark_dsl_config) || %{}
      rescue
        ArgumentError ->
          try do
            resource.spark_dsl_config()
          rescue
            _ ->
              reraise ArgumentError,
                      """
                      No such entity #{inspect(resource)} found.
                      """,
                      __STACKTRACE__
          end
      end
  end

  @doc "Get the entities configured for a given section"
  def get_entities(map, path) when is_map(map) do
    Spark.Dsl.Transformer.get_entities(map, path) || []
  end

  def get_entities(resource, path) do
    dsl!(resource)[path][:entities] || []
  end

  @doc "Get a value that was persisted while transforming or compiling the resource, e.g `:primary_key`"
  def get_persisted(resource, key, default \\ nil)

  def get_persisted(map, key, default) when is_map(map) do
    Spark.Dsl.Transformer.get_persisted(map, key, default)
  end

  def get_persisted(resource, key, default) do
    Map.get(dsl!(resource)[:persist] || %{}, key, default)
  end

  @doc """
  Get an option value for a section at a given path.

  Checks to see if it has been overridden via configuration.
  """
  def get_opt(resource, path, value, default \\ nil, configurable? \\ false) do
    case fetch_opt(resource, path, value, configurable?) do
      {:ok, value} -> value
      :error -> default
    end
  end

  def fetch_opt(resource, path, value, configurable? \\ false)

  def fetch_opt(map, path, value, configurable?) when is_map(map) do
    if configurable? do
      case get_opt_config(Spark.Dsl.Transformer.get_persisted(map, :module), path, value) do
        {:ok, value} ->
          {:ok, value}

        _ ->
          Spark.Dsl.Transformer.fetch_option(map, path, value)
      end
    else
      Spark.Dsl.Transformer.fetch_option(map, path, value)
    end
  end

  def fetch_opt(resource, path, value, configurable?) do
    path = List.wrap(path)

    if configurable? do
      case get_opt_config(resource, path, value) do
        {:ok, value} ->
          {:ok, value}

        _ ->
          Keyword.fetch(dsl!(resource)[path][:opts] || [], value)
      end
    else
      Keyword.fetch(dsl!(resource)[path][:opts] || [], value)
    end
  end

  @doc """
  Generate a table of contents for a list of sections
  """
  def doc_index(sections, depth \\ 0) do
    sections
    |> Enum.flat_map(fn
      {_, entities} ->
        entities

      other ->
        [other]
    end)
    |> Enum.map_join("\n", fn
      section ->
        docs =
          if depth == 0 do
            String.duplicate(" ", depth + 1) <>
              "* [#{section.name}](#module-#{section.name})"
          else
            String.duplicate(" ", depth + 1) <> "* #{section.name}"
          end

        case List.wrap(section.entities) ++ List.wrap(Map.get(section, :sections)) do
          [] ->
            docs

          sections_and_entities ->
            docs <> "\n" <> doc_index(sections_and_entities, depth + 2)
        end
    end)
  end

  @doc """
  Generate documentation for a list of sections
  """
  def doc(sections, depth \\ 1) do
    Enum.map_join(sections, "\n\n", fn section ->
      String.duplicate("#", depth + 1) <>
        " " <>
        to_string(section.name) <> "\n\n" <> doc_section(section, depth)
    end)
  end

  def doc_section(section, depth \\ 1) do
    sections_and_entities = List.wrap(section.entities) ++ List.wrap(section.sections)

    table_of_contents =
      case sections_and_entities do
        [] ->
          ""

        sections_and_entities ->
          doc_index(sections_and_entities)
      end

    options = Spark.OptionsHelpers.docs(section.schema)

    examples =
      case section.examples do
        [] ->
          ""

        examples ->
          "Examples:\n" <> Enum.map_join(examples, &doc_example/1)
      end

    entities =
      Enum.map_join(section.entities, "\n\n", fn entity ->
        String.duplicate("#", depth + 2) <>
          " " <>
          to_string(entity.name) <>
          "\n\n" <>
          doc_entity(entity, depth + 2)
      end)

    sections =
      Enum.map_join(section.sections, "\n\n", fn section ->
        String.duplicate("#", depth + 2) <>
          " " <>
          to_string(section.name) <>
          "\n\n" <>
          doc_section(section, depth + 1)
      end)

    imports =
      case section.imports do
        [] ->
          ""

        mods ->
          "Imports:\n\n" <>
            Enum.map_join(mods, "\n", fn mod ->
              "* `#{inspect(mod)}`"
            end)
      end

    """
    #{section.describe}

    #{table_of_contents}

    #{examples}

    #{imports}

    ---

    #{options}

    #{entities}

    #{sections}
    """
  end

  def doc_entity(entity, depth \\ 1) do
    options = Spark.OptionsHelpers.docs(Keyword.drop(entity.schema, entity.hide))

    examples =
      case entity.examples do
        [] ->
          ""

        examples ->
          "Examples:\n" <> Enum.map_join(examples, &doc_example/1)
      end

    entities =
      Enum.flat_map(entity.entities, fn
        {_, entities} ->
          entities

        other ->
          [other]
      end)

    entities_doc =
      Enum.map_join(entities, "\n\n", fn entity ->
        String.duplicate("#", depth + 2) <>
          " " <>
          to_string(entity.name) <>
          "\n\n" <>
          doc_entity(entity, depth + 1)
      end)

    table_of_contents =
      case entities do
        [] ->
          ""

        entities ->
          doc_index(entities)
      end

    """
    #{entity.describe}

    #{table_of_contents}

    #{examples}

    #{options}

    #{entities_doc}
    """
  end

  def get_opt_config(resource, path, value) do
    with otp_app when not is_nil(otp_app) <- get_persisted(resource, :otp_app),
         {:ok, config} <- Application.fetch_env(otp_app, resource) do
      path
      |> List.wrap()
      |> Kernel.++([value])
      |> Enum.reduce_while({:ok, config}, fn key, {:ok, config} ->
        if Keyword.keyword?(config) do
          case Keyword.fetch(config, key) do
            {:ok, value} -> {:cont, {:ok, value}}
            :error -> {:halt, :error}
          end
        else
          {:halt, :error}
        end
      end)
    end
  end

  defp doc_example({description, example}) when is_binary(description) and is_binary(example) do
    """
    #{description}
    ```
    #{example}
    ```
    """
  end

  defp doc_example(example) when is_binary(example) do
    """
    ```
    #{example}
    ```
    """
  end

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [
            sections: opts[:sections] || [],
            transformers: opts[:transformers] || [],
            verifiers: opts[:verifiers] || [],
            dsl_patches: opts[:dsl_patches] || [],
            module_prefix: opts[:module_prefix]
          ],
          generated: true do
      alias Spark.Dsl.Extension
      module_prefix = module_prefix || __MODULE__

      @behaviour Extension
      Extension.build(__MODULE__, module_prefix, sections, dsl_patches)
      @_sections sections
      @_transformers transformers
      @_verifiers verifiers
      @_dsl_patches dsl_patches

      @doc false
      def sections, do: set_docs(@_sections)
      @doc false
      def verifiers, do: [Spark.Dsl.Verifiers.VerifyEntityUniqueness | @_verifiers]
      @doc false
      def module_prefix, do: unquote(module_prefix) || __MODULE__
      @doc false
      def transformers, do: @_transformers
      @doc false
      def dsl_patches, do: @_dsl_patches

      defp set_docs(items) when is_list(items) do
        Enum.map(items, &set_docs/1)
      end

      defp set_docs(%Spark.Dsl.Entity{} = entity) do
        entity
        |> Map.put(:docs, Spark.Dsl.Extension.doc_entity(entity))
        |> Map.put(
          :entities,
          Enum.map(entity.entities || [], fn {key, value} -> {key, set_docs(value)} end)
        )
      end

      defp set_docs(%Spark.Dsl.Section{} = section) do
        section
        |> Map.put(:entities, set_docs(section.entities))
        |> Map.put(:sections, set_docs(section.sections))
        |> Map.put(:docs, Spark.Dsl.Extension.doc_section(section))
      end
    end
  end

  @doc false
  def explain(spark, opts, extensions, dsl_state) do
    prefix =
      case spark.explain(dsl_state, opts) do
        nil ->
          ""

        explanation ->
          """
          #{explanation}

          """
      end

    extension_explanations =
      extensions
      |> Enum.filter(&function_exported?(&1, :explain, 1))
      |> Enum.map(& &1.explain(dsl_state))
      |> Enum.reject(fn docs -> docs in [nil, ""] end)
      |> Enum.join("\n\n")

    prefix <> extension_explanations
  end

  @doc false
  def prepare(extensions) do
    body =
      quote generated: true, location: :keep do
        @extensions unquote(extensions)
        @persist {:spark_extensions, @extensions}
      end

    imports =
      for extension <- extensions || [] do
        extension = Macro.expand_once(extension, __ENV__)

        only_sections =
          extension.sections()
          |> Enum.map(&{&1.name, 1})

        quote generated: true, location: :keep do
          require Spark.Dsl.Extension
          import unquote(extension), only: unquote(only_sections)
        end
      end

    [body | imports]
  end

  @doc false
  defmacro set_state(additional_persisted_data, transform? \\ true) do
    quote generated: true,
          location: :keep,
          bind_quoted: [
            additional_persisted_data: additional_persisted_data,
            transform?: transform?
          ] do
      alias Spark.Dsl.Transformer

      persist =
        additional_persisted_data
        |> Keyword.put(:extensions, @extensions || [])
        |> Enum.into(%{})

      spark_dsl_config =
        {__MODULE__, :spark_sections}
        |> Process.get([])
        |> Enum.map(fn {_extension, section_path} ->
          {section_path,
           Process.get(
             {__MODULE__, :spark, section_path},
             []
           )}
        end)
        |> Enum.into(%{})
        |> Map.update(
          :persist,
          persist,
          &Map.merge(&1, persist)
        )

      for {key, _value} <- Process.get() do
        if is_tuple(key) and elem(key, 0) == __MODULE__ do
          Process.delete(key)
        end
      end

      transformers_to_run =
        if transform? do
          @extensions
          |> Enum.flat_map(& &1.transformers())
          |> Transformer.sort()
          |> Enum.reject(& &1.after_compile?())
        else
          []
        end

      @spark_dsl_config __MODULE__
                        |> Spark.Dsl.Extension.run_transformers(
                          transformers_to_run,
                          spark_dsl_config,
                          __ENV__
                        )
    end
  end

  def run_transformers(mod, transformers, spark_dsl_config, env) do
    Enum.reduce_while(transformers, spark_dsl_config, fn transformer, dsl ->
      result =
        try do
          transformer.transform(dsl)
        rescue
          e in Spark.Error.DslError ->
            reraise %{e | module: mod}, __STACKTRACE__

          e ->
            if Exception.exception?(e) do
              reraise e, __STACKTRACE__
            else
              reraise "Exception in transformer #{inspect(transformer)} on #{inspect(mod)}: \n\n#{Exception.message(e)}",
                      __STACKTRACE__
            end
        end

      case result do
        :ok ->
          {:cont, dsl}

        :halt ->
          {:halt, dsl}

        {:warn, new_dsl, warnings} ->
          warnings
          |> List.wrap()
          |> Enum.each(&IO.warn(&1, Macro.Env.stacktrace(env)))

          {:cont, new_dsl}

        {:ok, new_dsl} ->
          {:cont, new_dsl}

        {:error, %Spark.Error.DslError{} = e} ->
          raise_transformer_error(transformer, %{e | module: mod})

        {:error, error} ->
          raise_transformer_error(transformer, error)
      end
    end)
  end

  defp raise_transformer_error(transformer, error) do
    if Exception.exception?(error) do
      raise error
    else
      raise "Error while running transformer #{inspect(transformer)}: #{inspect(error)}"
    end
  end

  @doc false
  def all_section_paths(path, prior \\ [])
  def all_section_paths(nil, _), do: []
  def all_section_paths([], _), do: []

  def all_section_paths(sections, prior) do
    Enum.flat_map(sections, fn section ->
      nested = all_section_paths(section.sections, [section.name, prior])

      [Enum.reverse(prior) ++ [section.name] | nested]
    end)
    |> Enum.uniq()
  end

  @doc false
  def all_section_config_paths(path, prior \\ [])
  def all_section_config_paths(nil, _), do: []
  def all_section_config_paths([], _), do: []

  def all_section_config_paths(sections, prior) do
    Enum.flat_map(sections, fn section ->
      nested = all_section_config_paths(section.sections, [section.name, prior])

      fields =
        Enum.map(section.schema, fn {key, _} ->
          {Enum.reverse(prior) ++ [section.name], key}
        end)

      fields ++ nested
    end)
    |> Enum.uniq()
  end

  @doc false
  defmacro build(extension, module_prefix, sections, dsl_patches) do
    quote generated: true,
          bind_quoted: [
            dsl_patches: dsl_patches,
            sections: sections,
            extension: extension,
            module_prefix: module_prefix
          ] do
      alias Spark.Dsl.Extension

      {:ok, agent} = Agent.start_link(fn -> [] end)
      agent_and_pid = {agent, self()}

      # This won't work for nested recursive entities (that don't appear in the top level)
      # but I'm not aware of anyone doing anything like that, and so I'm okay with it for now
      all_recursive_entity_module_names =
        sections
        |> Enum.flat_map(fn section ->
          section.entities
          |> Enum.filter(& &1.recursive_as)
          |> Enum.map(fn entity ->
            mod_name =
              Module.concat([
                module_prefix,
                Macro.camelize(to_string(section.name)),
                Macro.camelize(to_string(entity.name)),
                Options
              ])

            quote generated: true do
              import unquote(mod_name), only: []
            end
          end)
        end)

      Enum.each(sections, fn section ->
        Spark.Dsl.Extension.async_compile(agent_and_pid, fn ->
          Extension.build_section(
            agent_and_pid,
            extension,
            section,
            all_recursive_entity_module_names,
            [],
            module_prefix
          )
        end)
      end)

      Enum.each(dsl_patches, fn %Spark.Dsl.Patch.AddEntity{
                                  section_path: section_path,
                                  entity: entity
                                } ->
        Spark.Dsl.Extension.async_compile(agent_and_pid, fn ->
          Extension.build_entity(
            agent_and_pid,
            module_prefix,
            extension,
            section_path,
            entity,
            [],
            [],
            []
          )
        end)
      end)

      Spark.Dsl.Extension.await_all_tasks(agent)

      Agent.stop(agent)
    end
  end

  @doc false
  defmacro build_section(
             agent,
             extension,
             section,
             unimports \\ [],
             path \\ [],
             module_prefix \\ nil
           ) do
    quote bind_quoted: [
            agent: agent,
            section: section,
            path: path,
            extension: extension,
            module_prefix: module_prefix,
            unimports: unimports
          ],
          generated: true do
      alias Spark.Dsl

      {section_modules, entity_modules, unimport_modules, opts_module} =
        Dsl.Extension.do_build_section(
          agent,
          module_prefix,
          extension,
          section,
          path,
          unimports
        )

      @doc false
      # This macro argument is only called `body` so that it looks nicer
      # in the DSL docs

      @doc false
      defmacro unquote(section.name)(body) do
        opts_module = unquote(opts_module)
        section_path = unquote(path ++ [section.name])
        section = unquote(Macro.escape(section))
        unimports = unquote(Macro.escape(unimports))
        unimport_modules = unquote(Macro.escape(unimport_modules))

        configured_imports =
          for module <- unquote(section.imports) do
            quote generated: true do
              import unquote(module)
            end
          end

        entity_imports =
          for module <- unquote(entity_modules) do
            quote generated: true do
              import unquote(module), only: :macros
            end
          end

        section_imports =
          for module <- unquote(section_modules) do
            quote generated: true do
              import unquote(module), only: :macros
            end
          end

        opts_import =
          if Map.get(unquote(Macro.escape(section)), :schema, []) == [] do
            []
          else
            [
              quote generated: true do
                import unquote(opts_module)
              end
            ]
          end

        configured_unimports =
          for module <- unquote(section.imports) do
            quote generated: true do
              import unquote(module), only: []
            end
          end

        entity_unimports =
          for module <- unquote(unimport_modules) do
            quote generated: true do
              import unquote(module), only: []
            end
          end

        section_unimports =
          for module <- unquote(section_modules) do
            quote generated: true do
              import unquote(module), only: []
            end
          end

        opts_unimport =
          if Map.get(unquote(Macro.escape(section)), :schema, []) == [] do
            []
          else
            [
              quote generated: true do
                import unquote(opts_module), only: []
              end
            ]
          end

        entity_modules = unquote(entity_modules)

        patch_modules =
          __CALLER__.module
          |> Module.get_attribute(:extensions, [])
          |> Spark.Dsl.Extension.get_entity_dsl_patches(section_path)
          |> Enum.reject(&(&1 in entity_modules))

        patch_module_imports =
          Enum.map(patch_modules, fn patch_module ->
            quote do
              import unquote(patch_module), only: :macros
            end
          end)

        patch_module_unimports =
          Enum.map(patch_modules, fn patch_module ->
            quote do
              import unquote(patch_module), only: []
            end
          end)

        entity_imports ++
          section_imports ++
          opts_import ++
          configured_imports ++
          patch_module_imports ++
          unimports ++
          [
            quote generated: true do
              unquote(body[:do])

              current_config =
                Process.get(
                  {__MODULE__, :spark, unquote(section_path)},
                  %{entities: [], opts: []}
                )

              opts =
                case Spark.OptionsHelpers.validate(
                       current_config.opts,
                       Map.get(unquote(Macro.escape(section)), :schema, [])
                     ) do
                  {:ok, opts} ->
                    opts

                  {:error, error} ->
                    raise Spark.Error.DslError,
                      module: __MODULE__,
                      message: error,
                      path: unquote(section_path)
                end

              Process.put(
                {__MODULE__, :spark, unquote(section_path)},
                %{
                  entities: current_config.entities,
                  opts: opts
                }
              )
            end
          ] ++
          configured_unimports ++
          patch_module_unimports ++
          opts_unimport ++ entity_unimports ++ section_unimports
      end
    end
  end

  defp entity_mod_name(mod, nested_entity_path, section_path, entity) do
    nested_entity_parts = Enum.map(nested_entity_path, &Macro.camelize(to_string(&1)))
    section_path_parts = Enum.map(section_path, &Macro.camelize(to_string(&1)))

    mod_parts =
      Enum.concat([
        [mod],
        section_path_parts,
        nested_entity_parts,
        [Macro.camelize(to_string(entity.name))]
      ])

    Module.concat(mod_parts)
  end

  defp section_mod_name(mod, path, section) do
    nested_mod_name =
      path
      |> Enum.drop(1)
      |> Enum.map(fn nested_section_name ->
        Macro.camelize(to_string(nested_section_name))
      end)

    Module.concat([mod | nested_mod_name] ++ [Macro.camelize(to_string(section.name))])
  end

  defp unimports(mod, section, path, opts_mod_name) do
    entity_modules =
      section.entities
      |> Enum.reject(& &1.recursive_as)
      |> Enum.map(fn entity ->
        entity_mod_name(mod, [], path ++ [section.name], entity)
      end)

    entity_unimports =
      for module <- entity_modules do
        quote generated: true do
          import unquote(module), only: []
        end
      end

    section_modules =
      Enum.map(section.sections, fn section ->
        section_mod_name(mod, path, section)
      end)

    section_unimports =
      for module <- section_modules do
        quote generated: true do
          import unquote(module), only: []
        end
      end

    opts_unimport =
      if section.schema == [] do
        []
      else
        [
          quote generated: true do
            import unquote(opts_mod_name), only: []
          end
        ]
      end

    opts_unimport ++ section_unimports ++ entity_unimports
  end

  @doc false
  def do_build_section(agent, mod, extension, section, path, unimports) do
    opts_mod_name =
      if section.schema == [] do
        nil
      else
        Module.concat([mod, Macro.camelize(to_string(section.name)), Options])
      end

    {entity_modules, unimport_modules} =
      Enum.reduce(section.entities, {[], []}, fn entity, {entity_modules, unimport_mods} ->
        entity = %{
          entity
          | auto_set_fields: Keyword.merge(section.auto_set_fields, entity.auto_set_fields)
        }

        new_unimports =
          if entity.recursive_as do
            if opts_mod_name do
              [
                quote generated: true do
                  import unquote(opts_mod_name), only: []
                end
              ]
            else
              []
            end
          else
            unimports(
              mod,
              %{section | entities: Enum.reject(section.entities, &(&1.name == entity.name))},
              path,
              opts_mod_name
            )
          end

        entity_mod =
          build_entity(
            agent,
            mod,
            extension,
            path ++ [section.name],
            entity,
            section.deprecations,
            [],
            unimports ++ new_unimports
          )

        if entity.recursive_as do
          {[entity_mod | entity_modules], unimport_mods}
        else
          {[entity_mod | entity_modules], [entity_mod | unimport_mods]}
        end
      end)

    section_modules =
      Enum.map(section.sections, fn nested_section ->
        nested_mod_name =
          path
          |> Enum.drop(1)
          |> Enum.map(fn nested_section_name ->
            Macro.camelize(to_string(nested_section_name))
          end)

        mod_name =
          Module.concat(
            [mod | nested_mod_name] ++ [Macro.camelize(to_string(nested_section.name))]
          )

        Spark.Dsl.Extension.async_compile(agent, fn ->
          {:module, module, _, _} =
            Module.create(
              mod_name,
              quote generated: true do
                @moduledoc false
                alias Spark.Dsl

                require Dsl.Extension

                Dsl.Extension.build_section(
                  unquote(agent),
                  unquote(extension),
                  unquote(Macro.escape(nested_section)),
                  unquote(unimports),
                  unquote(path ++ [section.name]),
                  nil
                )
              end,
              Macro.Env.location(__ENV__)
            )

          module
        end)

        mod_name
      end)

    if opts_mod_name do
      Module.create(
        opts_mod_name,
        quote generated: true,
              bind_quoted: [
                section: Macro.escape(section),
                section_path: path ++ [section.name],
                extension: extension
              ] do
          @moduledoc false
          for {field, config} <- section.schema do
            defmacro unquote(field)(value) do
              section_path = unquote(Macro.escape(section_path))
              field = unquote(Macro.escape(field))
              extension = unquote(extension)
              config = unquote(Macro.escape(config))
              section = unquote(Macro.escape(section))

              value =
                if config[:type] == :quoted do
                  Macro.escape(value)
                else
                  value
                end

              Spark.Dsl.Extension.maybe_deprecated(
                field,
                section.deprecations,
                section_path,
                __CALLER__
              )

              value =
                cond do
                  field in section.modules ->
                    Spark.Dsl.Extension.expand_alias(value, __CALLER__)

                  field in section.no_depend_modules ->
                    Spark.Dsl.Extension.expand_alias_no_require(value, __CALLER__)

                  true ->
                    value
                end

              {value, function} = Spark.CodeHelpers.lift_functions(value, field, __CALLER__)

              quote generated: true do
                unquote(function)

                Spark.Dsl.Extension.set_section_opt(
                  unquote(value),
                  unquote(Macro.escape(value)),
                  unquote(Macro.escape(config[:type])),
                  unquote(section_path),
                  unquote(extension),
                  unquote(field)
                )
              end
            end
          end
        end,
        Macro.Env.location(__ENV__)
      )
    end

    {section_modules, entity_modules, unimport_modules, opts_mod_name}
  end

  defmacro set_section_opt(
             value,
             escaped_value,
             type,
             section_path,
             extension,
             field
           ) do
    {value, function} = Spark.CodeHelpers.lift_functions(value, field, __CALLER__)

    quote generated: true,
          bind_quoted: [
            value: value,
            escaped_value: escaped_value,
            type: type,
            section_path: section_path,
            extension: extension,
            field: field,
            function: function
          ] do
      current_sections = Process.get({__MODULE__, :spark_sections}, [])

      unless {extension, section_path} in current_sections do
        Process.put({__MODULE__, :spark_sections}, [
          {extension, section_path} | current_sections
        ])
      end

      current_config =
        Process.get(
          {__MODULE__, :spark, section_path},
          %{entities: [], opts: []}
        )

      Process.put(
        {__MODULE__, :spark, section_path},
        %{
          current_config
          | opts: Keyword.put(current_config.opts, field, value)
        }
      )
    end
  end

  @doc false
  # sobelow_skip ["DOS.BinToAtom"]
  def build_entity(
        agent,
        mod,
        extension,
        section_path,
        entity,
        deprecations,
        nested_entity_path,
        unimports,
        nested_key \\ nil
      ) do
    mod_name = entity_mod_name(mod, nested_entity_path, section_path, entity)

    options_mod_name = Module.concat(mod_name, "Options")

    {nested_entity_mods, nested_entity_unimports} =
      Enum.reduce(entity.entities, {[], []}, fn
        {key, entities}, {nested_entity_mods, nested_entity_unimports} ->
          entities
          |> List.wrap()
          |> Enum.reduce(
            {nested_entity_mods, nested_entity_unimports},
            fn nested_entity, {nested_entity_mods, nested_entity_unimports} ->
              entities_to_unimport =
                entity.entities
                |> Enum.flat_map(fn {key, entities} ->
                  entities
                  |> List.wrap()
                  |> Enum.reject(&(&1.name == nested_entity.name))
                  |> Enum.flat_map(fn nested_entity ->
                    if nested_entity.recursive_as do
                      []
                    else
                      [
                        entity_mod_name(
                          mod_name,
                          nested_entity_path ++ [key],
                          section_path,
                          nested_entity
                        )
                      ]
                    end
                  end)
                end)

              unimports =
                unimports ++
                  Enum.map(
                    [options_mod_name | entities_to_unimport],
                    fn mod_name ->
                      quote generated: true do
                        import unquote(mod_name), only: []
                      end
                    end
                  )

              entity_mod =
                build_entity(
                  agent,
                  mod_name,
                  extension,
                  section_path,
                  nested_entity,
                  nested_entity.deprecations,
                  nested_entity_path ++ [key],
                  unimports,
                  key
                )

              {[entity_mod | nested_entity_mods],
               [entity_mod | nested_entity_unimports] ++ entities_to_unimport}
            end
          )
      end)

    Spark.Dsl.Extension.build_entity_options(
      options_mod_name,
      entity,
      nested_entity_path
    )

    args =
      entity.args
      |> Enum.map(fn
        {:optional, name} ->
          {:optional, name, nil}

        other ->
          other
      end)
      |> Enum.map(fn
        {:optional, name, default} ->
          {:\\, [], [{name, [], Elixir}, default]}

        other ->
          Macro.var(other, Elixir)
      end)

    entity_args = Spark.Dsl.Entity.arg_names(entity)
    arg_vars = Enum.map(entity_args, &Macro.var(&1, Elixir))

    unimports =
      Enum.reject(unimports, fn
        {:import, _, [^options_mod_name, _]} ->
          true

        _ ->
          false
      end)

    async_compile(agent, fn ->
      Module.create(
        mod_name,
        quote generated: true,
              location: :keep,
              bind_quoted: [
                extension: extension,
                entity: Macro.escape(entity),
                args: Macro.escape(args),
                arg_vars: Macro.escape(arg_vars),
                section_path: Macro.escape(section_path),
                entity_args: Macro.escape(entity_args),
                options_mod_name: Macro.escape(options_mod_name),
                nested_entity_unimports: Macro.escape(nested_entity_unimports),
                nested_entity_mods: Macro.escape(nested_entity_mods),
                nested_entity_path: Macro.escape(nested_entity_path),
                deprecations: deprecations,
                unimports: Macro.escape(unimports),
                nested_key: nested_key
              ] do
          @moduledoc false
          defmacro unquote(entity.name)(unquote_splicing(args), opts \\ nil) do
            section_path = unquote(Macro.escape(section_path))
            entity_schema = unquote(Macro.escape(entity.schema))
            entity = unquote(Macro.escape(entity))
            entity_name = unquote(Macro.escape(entity.name))
            entity_args = unquote(Macro.escape(entity_args))
            arg_vars = unquote(Macro.escape(arg_vars))
            entity_deprecations = unquote(entity.deprecations)
            options_mod_name = unquote(Macro.escape(options_mod_name))
            source = unquote(__MODULE__)
            extension = unquote(Macro.escape(extension))
            nested_entity_mods = unquote(Macro.escape(nested_entity_mods))
            nested_entity_unimports = unquote(Macro.escape(nested_entity_unimports))
            nested_entity_path = unquote(Macro.escape(nested_entity_path))
            deprecations = unquote(deprecations)
            unimports = unquote(Macro.escape(unimports))
            nested_key = unquote(nested_key)

            require Spark.Dsl.Extension

            Spark.Dsl.Extension.maybe_deprecated(
              entity.name,
              deprecations,
              section_path ++ nested_entity_path,
              __CALLER__
            )

            {args_without_opts, opts} =
              entity_args
              |> Enum.zip([unquote_splicing(arg_vars)])
              |> Spark.Dsl.Extension.escape_quoted(entity_schema)
              |> Spark.Dsl.Extension.shuffle_opts_to_end(unquote(Macro.escape(entity.args)), opts)

            {arg_values, funs} =
              args_without_opts
              |> Enum.reduce({[], []}, fn {key, arg_value}, {args, funs} ->
                type = entity_schema[key][:type]

                Spark.Dsl.Extension.maybe_deprecated(
                  key,
                  entity_deprecations,
                  nested_entity_path,
                  __CALLER__
                )

                arg_value =
                  cond do
                    key in entity.modules ->
                      Spark.Dsl.Extension.expand_alias(arg_value, __CALLER__)

                    key in entity.no_depend_modules ->
                      Spark.Dsl.Extension.expand_alias_no_require(arg_value, __CALLER__)

                    true ->
                      arg_value
                  end

                {arg_value, new_function} =
                  Spark.CodeHelpers.lift_functions(arg_value, key, __CALLER__)

                {[arg_value | args], [new_function | funs]}
              end)

            arg_values = Enum.reverse(arg_values)

            imports =
              for module <- entity.imports do
                quote generated: true do
                  import unquote(module)
                end
              end

            opts =
              Enum.map(opts, fn {key, value} ->
                Spark.Dsl.Extension.maybe_deprecated(
                  key,
                  entity_deprecations,
                  nested_entity_path,
                  __CALLER__
                )

                cond do
                  key in entity.modules ->
                    {key, Spark.Dsl.Extension.expand_alias(value, __CALLER__)}

                  key in entity.no_depend_modules ->
                    {key, Spark.Dsl.Extension.expand_alias_no_require(value, __CALLER__)}

                  true ->
                    {key, value}
                end
              end)

            code =
              unimports ++
                imports ++
                funs ++
                [
                  quote generated: true do
                    section_path = unquote(section_path)
                    entity_name = unquote(entity_name)
                    extension = unquote(extension)
                    recursive_as = unquote(entity.recursive_as)
                    nested_key = unquote(nested_key)
                    parent_recursive_as = Process.get(:parent_recursive_as)

                    original_nested_entity_path = Process.get(:recursive_builder_path)

                    nested_entity_path =
                      if is_nil(original_nested_entity_path) do
                        Process.put(:recursive_builder_path, [])
                        []
                      else
                        unless recursive_as || nested_key || parent_recursive_as do
                          raise "Somehow got a nested entity without a `recursive_as` or `nested_key`"
                        end

                        path =
                          (original_nested_entity_path || []) ++
                            [recursive_as || nested_key || parent_recursive_as]

                        Process.put(
                          :recursive_builder_path,
                          path
                        )

                        path
                      end

                    if recursive_as do
                      Process.put(:parent_recursive_as, recursive_as)
                    end

                    current_sections = Process.get({__MODULE__, :spark_sections}, [])

                    keyword_opts =
                      Keyword.merge(
                        unquote(Keyword.delete(opts, :do)),
                        Enum.zip(unquote(entity_args), unquote(arg_values))
                      )

                    Process.put(
                      {:builder_opts, nested_entity_path},
                      keyword_opts
                    )

                    import unquote(options_mod_name)

                    require Spark.Dsl.Extension
                    Spark.Dsl.Extension.import_mods(unquote(nested_entity_mods))

                    unquote(opts[:do])

                    Process.put(:recursive_builder_path, original_nested_entity_path)
                    Process.put(:parent_recursive_as, parent_recursive_as)

                    current_config =
                      Process.get(
                        {__MODULE__, :spark, section_path ++ nested_entity_path},
                        %{entities: [], opts: []}
                      )

                    import unquote(options_mod_name), only: []

                    require Spark.Dsl.Extension
                    Spark.Dsl.Extension.unimport_mods(unquote(nested_entity_mods))

                    opts = Process.delete({:builder_opts, nested_entity_path})

                    alias Spark.Dsl.Entity

                    nested_entity_keys =
                      unquote(Macro.escape(entity.entities))
                      |> Enum.map(&elem(&1, 0))
                      |> Enum.uniq()

                    nested_entities =
                      nested_entity_keys
                      |> Enum.reduce(%{}, fn key, acc ->
                        nested_path = section_path ++ nested_entity_path ++ [key]

                        entities =
                          {__MODULE__, :spark, nested_path}
                          |> Process.get(%{entities: []})
                          |> Map.get(:entities, [])

                        Process.delete({__MODULE__, :spark, nested_path})

                        Map.update(acc, key, entities, fn current_nested_entities ->
                          (current_nested_entities || []) ++ entities
                        end)
                      end)

                    built =
                      case Entity.build(unquote(Macro.escape(entity)), opts, nested_entities) do
                        {:ok, built} ->
                          built

                        {:error, error} ->
                          additional_path =
                            if opts[:name] do
                              [unquote(entity.name), opts[:name]]
                            else
                              [unquote(entity.name)]
                            end

                          message =
                            cond do
                              Exception.exception?(error) ->
                                Exception.message(error)

                              is_binary(error) ->
                                error

                              true ->
                                inspect(error)
                            end

                          raise Spark.Error.DslError,
                            module: __MODULE__,
                            message: message,
                            path: section_path ++ additional_path
                      end

                    new_config = %{current_config | entities: current_config.entities ++ [built]}

                    unless {extension, section_path} in current_sections do
                      Process.put({__MODULE__, :spark_sections}, [
                        {extension, section_path} | current_sections
                      ])
                    end

                    Process.put(
                      {__MODULE__, :spark, section_path ++ nested_entity_path},
                      new_config
                    )
                  end
                ]

            # This is (for some reason I'm not really sure why) necessary to keep the imports within a lexical scope
            quote generated: true do
              try do
                unquote(code)
              rescue
                e ->
                  reraise e, __STACKTRACE__
              end
            end
          end
        end,
        Macro.Env.location(__ENV__)
      )
    end)

    mod_name
  end

  defmacro import_mods(mods) do
    for mod <- mods do
      quote generated: true do
        import unquote(mod)
      end
    end
  end

  defmacro unimport_mods(mods) do
    for mod <- mods do
      quote generated: true do
        import unquote(mod), only: []
      end
    end
  end

  @doc false
  def build_entity_options(
        module_name,
        entity,
        nested_entity_path
      ) do
    entity =
      case entity.recursive_as do
        nil ->
          entity

        recursive_as ->
          %{entity | entities: Keyword.put_new(entity.entities || [], recursive_as, [])}
      end

    Module.create(
      module_name,
      quote generated: true,
            bind_quoted: [
              entity: Macro.escape(entity),
              nested_entity_path: nested_entity_path
            ] do
        @moduledoc false

        for {key, config} <- entity.schema do
          defmacro unquote(key)(value) do
            key = unquote(key)
            modules = unquote(entity.modules)
            no_depend_modules = unquote(entity.no_depend_modules)
            deprecations = unquote(entity.deprecations)
            entity_name = unquote(entity.name)
            recursive_as = unquote(entity.recursive_as)
            nested_entity_path = unquote(nested_entity_path)

            config = unquote(Macro.escape(config))

            value =
              if config[:type] == :quoted do
                Macro.escape(value)
              else
                value
              end

            Spark.Dsl.Extension.maybe_deprecated(
              key,
              deprecations,
              nested_entity_path,
              __CALLER__
            )

            value =
              cond do
                key in modules ->
                  Spark.Dsl.Extension.expand_alias(value, __CALLER__)

                key in no_depend_modules ->
                  Spark.Dsl.Extension.expand_alias_no_require(value, __CALLER__)

                true ->
                  value
              end

            {value, function} = Spark.CodeHelpers.lift_functions(value, key, __CALLER__)

            quote generated: true do
              unquote(function)

              Spark.Dsl.Extension.set_entity_opt(
                unquote(value),
                unquote(Macro.escape(value)),
                unquote(Macro.escape(config[:type])),
                unquote(key)
              )
            end
          end
        end
      end,
      file: __ENV__.file
    )

    module_name
  end

  @doc false
  def escape_quoted(options, schema) do
    Enum.map(options, fn {name, value} ->
      if schema[name][:type] == :quoted do
        {name, Macro.escape(value)}
      else
        {name, value}
      end
    end)
  end

  defmacro set_entity_opt(
             value,
             escaped_value,
             type,
             key
           ) do
    {value, function} = Spark.CodeHelpers.lift_functions(value, key, __CALLER__)

    quote generated: true,
          bind_quoted: [
            value: value,
            escaped_value: escaped_value,
            type: type,
            key: key,
            function: function
          ] do
      nested_entity_path = Process.get(:recursive_builder_path)

      current_opts = Process.get({:builder_opts, nested_entity_path}, [])

      Process.put(
        {:builder_opts, nested_entity_path},
        Keyword.put(current_opts, key, value)
      )
    end
  end

  @doc false
  def maybe_deprecated(field, deprecations, path, env) do
    if Keyword.has_key?(deprecations, field) do
      prefix =
        case Enum.join(path) do
          "" -> ""
          path -> "#{path}."
        end

      IO.warn(
        "The #{prefix}#{field} key will be deprecated in an upcoming release!\n\n#{deprecations[field]}",
        Macro.Env.stacktrace(env)
      )
    end
  end

  def expand_alias(ast, %Macro.Env{} = env) do
    Macro.postwalk(ast, fn
      {:__aliases__, _, _} = node ->
        # This is basically just `Macro.expand_literal/2`
        do_expand(node, %{env | function: {:module_info, 0}})

      other ->
        other
    end)
  end

  def expand_alias_no_require(ast, env) do
    Macro.postwalk(ast, fn
      {:__aliases__, _, parts} = node ->
        expanded = do_expand(node, %{env | lexical_tracker: nil})

        if is_atom(expanded) do
          try do
            alias_used =
              Enum.find_value(env.aliases, fn {alias_value, destination} ->
                if List.last(Module.split(destination)) ==
                     to_string(List.first(parts)) do
                  alias_value
                end
              end)

            if alias_used do
              # Dear Jose, I know you would hate this if you saw it 😢.
              # I will propose a utility for doing this with a public
              # API soon, but this had to do for the short term.

              Kernel.LexicalTracker.alias_dispatch(env.lexical_tracker, alias_used)
            end
          rescue
            _e ->
              :ok
          end
        end

        expanded

      other ->
        other
    end)
  end

  @doc false
  def do_expand(ast, env) do
    {ast, :ok} = expand_literals(ast, :ok, fn node, :ok -> {Macro.expand(node, env), :ok} end)
    ast
  end

  def expand_literals(ast, acc, fun)

  def expand_literals({:__aliases__, meta, args}, acc, fun) do
    {args, acc} = expand_literals(args, acc, fun)

    if :lists.all(&is_atom/1, args) do
      fun.({:__aliases__, meta, args}, acc)
    else
      {{:__aliases__, meta, args}, acc}
    end
  end

  def expand_literals({:__MODULE__, _meta, ctx} = node, acc, fun) when is_atom(ctx) do
    fun.(node, acc)
  end

  def expand_literals({:%, meta, [left, right]}, acc, fun) do
    {left, acc} = expand_literals(left, acc, fun)
    {right, acc} = expand_literals(right, acc, fun)
    {{:%, meta, [left, right]}, acc}
  end

  def expand_literals({:%{}, meta, args}, acc, fun) do
    {args, acc} = expand_literals(args, acc, fun)
    {{:%{}, meta, args}, acc}
  end

  def expand_literals({:{}, meta, args}, acc, fun) do
    {args, acc} = expand_literals(args, acc, fun)
    {{:{}, meta, args}, acc}
  end

  def expand_literals({left, right}, acc, fun) do
    {left, acc} = expand_literals(left, acc, fun)
    {right, acc} = expand_literals(right, acc, fun)
    {{left, right}, acc}
  end

  def expand_literals(list, acc, fun) when is_list(list) do
    :lists.mapfoldl(&expand_literals(&1, &2, fun), acc, list)
  end

  def expand_literals(
        {{:., _, [{:__aliases__, _, [:Application]}, :compile_env]} = node, meta,
         [app, key, default]},
        acc,
        fun
      ) do
    {default, acc} = expand_literals(default, acc, fun)
    {{node, meta, [app, key, default]}, acc}
  end

  def expand_literals(term, acc, _fun), do: {term, acc}

  def monotonic_number(key) do
    (Process.get({:spark_monotonic_number, key}) || -1) + 1
  end

  def spark_function_info({:or, types}) do
    Enum.find_value(types, &spark_function_info/1)
  end

  def spark_function_info({:spark_function_behaviour, _, _, {module, arity}}) do
    {module, arity}
  end

  def spark_function_info({:spark_function_behaviour, _, {module, arity}}) do
    {module, arity}
  end

  def spark_function_info(_) do
    nil
  end

  def shuffle_opts_to_end(keyword, entity_args, nil) do
    case Enum.find_index(keyword, fn {_key, value} -> Keyword.keyword?(value) end) do
      nil ->
        {keyword, []}

      index ->
        key = keyword |> Enum.at(index) |> elem(0)

        default =
          Enum.find_value(entity_args, fn
            {:optional, ^key, default} ->
              default

            _ ->
              nil
          end)

        {List.replace_at(keyword, index, {key, default}), keyword |> Enum.at(index) |> elem(1)}
    end
  end

  def shuffle_opts_to_end(keyword, _entity_args, opts) do
    {keyword, opts}
  end

  @doc false
  def await_all_tasks(agent) do
    Agent.get_and_update(
      agent,
      fn state ->
        case state do
          [] ->
            {:stop, []}

          funs ->
            {{:tasks, funs}, []}
        end
      end,
      :infinity
    )
    |> case do
      :stop ->
        :ok

      {:tasks, funs} ->
        funs
        |> Enum.map(fn func ->
          case :erlang.get(:elixir_compiler_info) do
            :undefined ->
              Task.async(func)

            _ ->
              Kernel.ParallelCompiler.async(func)
          end
        end)
        |> Task.await_many(:infinity)

        await_all_tasks(agent)
    end
  end

  @doc false
  def async_compile({agent, _pid}, func) do
    Agent.update(
      agent,
      fn funs ->
        [func | funs]
      end,
      :infinity
    )
  end

  def get_entity_dsl_patches(extensions, section_path) do
    patches =
      extensions
      |> Enum.flat_map(fn extension ->
        extension.dsl_patches()
        |> Enum.filter(&(&1.section_path == section_path))
        |> Enum.map(&{extension, &1})
      end)

    if !section_patchable?(extensions, section_path) && Enum.any?(patches) do
      IO.warn("Attempt to patch a DSL section which is not marked as patchable")
      []
    else
      patches
      |> Enum.map(fn
        {extension, patch} when is_struct(patch, Spark.Dsl.Patch.AddEntity) ->
          entity_mod_name(extension.module_prefix(), [], section_path, patch.entity)
      end)
    end
  end

  defp section_patchable?(extensions, section_path) do
    extensions
    |> Enum.flat_map(& &1.sections())
    |> get_section_at_path(section_path, %{})
    |> Map.get(:patchable?, false)
  end

  defp get_section_at_path(sections, [name], default) do
    sections
    |> Enum.filter(&(&1.name == name))
    |> case do
      [section] -> section
      [] -> default
    end
  end

  defp get_section_at_path(sections, [head | tail], default) do
    sections
    |> Enum.filter(&(&1.name == head))
    |> Enum.flat_map(& &1.sections)
    |> get_section_at_path(tail, default)
  end
end
