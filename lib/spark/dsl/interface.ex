defmodule Spark.Dsl.Interface do
  @moduledoc """
  Allows creating interface definitions that other DSL resources can implement.

  Unlike fragments which merge their configuration into parent resources, interfaces
  define contracts that implementing resources must fulfill. Interfaces use placeholder
  values instead of defaults, and validation ensures implementing resources provide
  all required values.

  ## Usage

  Define an interface:

      defmodule MyApp.Resource.Interface do
        use Spark.Dsl.Interface, for: Ash.Resource

        attributes do
          uuid_primary_key :id
          attribute :name, :string do
            allow_nil? false
          end
        end

        actions do
          defaults [:read, :create, :update, :destroy]
        end
      end

  Implement the interface in a resource:

      defmodule MyApp.User do
        use Ash.Resource, interfaces: [MyApp.Resource.Interface]

        attributes do
          # Must provide the required interface attributes
          uuid_primary_key :id
          attribute :name, :string do
            allow_nil? false
          end
          # Can add additional attributes
          attribute :email, :string
        end

        actions do
          defaults [:read, :create, :update, :destroy]
          # Can add additional actions
        end
      end

  ## Validation

  At compile time, the interface system validates that implementing resources
  provide all required values from the interface definition. Values marked as
  placeholders in the interface are not required to be present.
  """

  alias Spark.Dsl.Interface.Placeholder

  defmacro __using__(opts) do
    opts = Spark.Dsl.Extension.do_expand(opts, __CALLER__)
    original_opts = opts
    target_dsl = opts[:for]

    unless target_dsl do
      raise ArgumentError, "Interface must specify a target DSL with `for: TargetDsl`"
    end

    single_extension_kinds = target_dsl.single_extension_kinds()
    many_extension_kinds = target_dsl.many_extension_kinds()

    {_opts, extensions} =
      target_dsl.default_extension_kinds()
      |> Enum.reduce(opts, fn {key, defaults}, opts ->
        Keyword.update(opts, key, defaults, fn current_value ->
          cond do
            key in single_extension_kinds ->
              current_value || defaults

            key in many_extension_kinds || key == :extensions ->
              List.wrap(current_value) ++ List.wrap(defaults)

            true ->
              current_value
          end
        end)
      end)
      |> Spark.Dsl.expand_modules(
        [
          single_extension_kinds: single_extension_kinds,
          many_extension_kinds: many_extension_kinds
        ],
        __CALLER__
      )

    extensions =
      extensions
      |> Enum.flat_map(&[&1 | &1.add_extensions()])
      |> Enum.uniq()

    Module.register_attribute(__CALLER__.module, :spark_extension_kinds, persist: true)
    Module.register_attribute(__CALLER__.module, :spark_interface_for, persist: true)

    Module.put_attribute(__CALLER__.module, :spark_interface_for, target_dsl)
    Module.put_attribute(__CALLER__.module, :extensions, extensions)
    Module.put_attribute(__CALLER__.module, :original_opts, original_opts)

    Module.put_attribute(
      __CALLER__.module,
      :spark_extension_kinds,
      List.wrap(many_extension_kinds) ++
        List.wrap(single_extension_kinds)
    )

    quote do
      require unquote(target_dsl)
      unquote(prepare_interface_extensions(extensions))
      @before_compile Spark.Dsl.Interface
    end
  end

  defp prepare_interface_extensions(extensions) do
    # Use the same extension preparation as regular DSL
    Spark.Dsl.Extension.prepare(extensions)
  end

  defmacro __before_compile__(_) do
    quote do
      # Set up interface-specific state without validation
      Spark.Dsl.Extension.set_state([], [], false)

      def extensions do
        @extensions
      end

      def opts do
        @original_opts
      end

      def spark_dsl_config do
        @spark_dsl_config
      end

      def validate_sections do
        List.wrap(@validate_sections)
      end

      def interface_for do
        @spark_interface_for
      end

      def is_interface? do
        true
      end

      # Interface-specific functions
      def interface_contract do
        # Return the DSL configuration with placeholders
        @spark_dsl_config
      end

      def required_values do
        # Extract all non-placeholder values from the interface
        extract_required_values(@spark_dsl_config)
      end

      defp extract_required_values(config) do
        config
        |> Enum.flat_map(fn 
          {:persist, _} -> 
            # Skip the :persist key as it's not a section
            []
          
          {section_name, section_config} when is_list(section_name) ->
            # Process regular sections with their path
            extract_section_required_values(section_name, section_config)
            
          _ ->
            []
        end)
      end

      defp extract_section_required_values(section_path, section_config) do
        opts_values = 
          case section_config do
            %{opts: opts} when is_list(opts) ->
              extract_options_required_values(section_path, opts)
            _ ->
              []
          end
          
        entity_values = 
          case section_config do
            %{entities: entities} when is_list(entities) ->
              Enum.flat_map(entities, &extract_entity_required_values(section_path, &1))
            _ ->
              []
          end
          
        opts_values ++ entity_values
      end

      defp extract_entity_required_values(section_path, entity) do
        case entity do
          %{name: name, opts: opts} ->
            non_placeholder_opts = 
              opts
              |> Enum.reject(fn {_key, value} -> 
                Placeholder.placeholder?(value) 
              end)
            
            if non_placeholder_opts == [] do
              []
            else
              [{:entity, section_path, name, non_placeholder_opts}]
            end

          _ ->
            []
        end
      end

      defp extract_options_required_values(section_path, opts) do
        opts
        |> Enum.reject(fn {_key, value} -> 
          Placeholder.placeholder?(value) 
        end)
        |> Enum.map(fn {key, value} -> {:option, section_path, key, value} end)
      end

      @persisted @spark_dsl_config[:persist]

      def persisted do
        @persisted
      end
    end
  end

  @doc """
  Validates that a resource implements the given interface contract.

  This function is called at compile time to ensure that resources
  claiming to implement an interface actually provide all required values.
  """
  def validate_implementation(resource_module, interface_module) do
    _interface_contract = interface_module.interface_contract()
    resource_config = resource_module.spark_dsl_config()
    
    required_values = interface_module.required_values()
    
    validate_required_values(resource_config, required_values, interface_module, resource_module)
  end

  defp validate_required_values(resource_config, required_values, interface_module, resource_module) do
    missing_values = 
      required_values
      |> Enum.filter(fn required_value ->
        not value_present_in_resource?(resource_config, required_value)
      end)

    if missing_values != [] do
      raise_missing_values_error(missing_values, interface_module, resource_module)
    end

    :ok
  end

  defp value_present_in_resource?(resource_config, required_value) do
    case required_value do
      {:entity, section_path, name, opts} ->
        entity_present_with_options?(resource_config, section_path, name, opts)

      {:option, section_path, key, value} ->
        option_present_with_value?(resource_config, section_path, key, value)
    end
  end

  defp entity_present_with_options?(resource_config, section_path, entity_name, required_opts) do
    # Check if the resource has an entity with the given name and required options
    case Map.get(resource_config, section_path) do
      %{entities: entities} when is_list(entities) ->
        Enum.any?(entities, fn entity ->
          entity.name == entity_name and 
          options_match?(entity.opts, required_opts)
        end)

      _ ->
        false
    end
  end

  defp option_present_with_value?(resource_config, section_path, option_key, required_value) do
    # Check if the resource has an option with the given key and value
    case Map.get(resource_config, section_path) do
      %{opts: opts} when is_list(opts) ->
        Keyword.get(opts, option_key) == required_value

      _ ->
        false
    end
  end

  defp options_match?(entity_opts, required_opts) do
    Enum.all?(required_opts, fn {key, required_value} ->
      Keyword.get(entity_opts, key) == required_value
    end)
  end

  defp raise_missing_values_error(missing_values, interface_module, resource_module) do
    missing_descriptions = 
      missing_values
      |> Enum.map(fn
        {:entity, name, opts} ->
          "Entity #{name} with options #{inspect(opts)}"
        {:option, key, value} ->
          "Option #{key} with value #{inspect(value)}"
      end)
      |> Enum.join(", ")

    raise """
    Resource #{inspect(resource_module)} does not implement interface #{inspect(interface_module)}.
    
    Missing required values: #{missing_descriptions}
    
    The interface defines these as required, but they are not present in the implementing resource.
    """
  end
end