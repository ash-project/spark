defmodule Spark.Dsl do
  @using_schema [
    single_extension_kinds: [
      type: {:list, :atom},
      default: [],
      doc:
        "The extension kinds that are allowed to have a single value. For example: `[:data_layer]`"
    ],
    many_extension_kinds: [
      type: {:list, :atom},
      default: [],
      doc:
        "The extension kinds that can have multiple values. e.g `[notifiers: [Notifier1, Notifier2]]`"
    ],
    untyped_extensions?: [
      type: :boolean,
      default: true,
      doc: "Whether or not to support an `extensions` key which contains untyped extensions"
    ],
    default_extensions: [
      type: :keyword_list,
      default: [],
      doc: """
      The extensions that are included by default. e.g `[data_layer: Default, notifiers: [Notifier1]]`
      Default values for single extension kinds are overwritten if specified by the implementor, while many extension
      kinds are appended to if specified by the implementor.
      """
    ]
  ]

  @type entity :: %Spark.Dsl.Entity{}

  @type section :: %Spark.Dsl.Section{}

  @moduledoc """
  The primary entry point for adding a DSL to a module.

  To add a DSL to a module, add `use Spark.Dsl, ...options`. The options supported with `use Spark.Dsl` are:

  #{Spark.OptionsHelpers.docs(@using_schema)}

  See the callbacks defined in this module to augment the behavior/compilation of the module getting a Dsl.
  """

  @type opts :: Keyword.t()
  @doc """
  Validate/add options. Those options will be passed to `handle_opts` and `handle_before_compile`
  """
  @callback init(opts) :: {:ok, opts} | {:error, String.t() | term}
  @doc """
  Handle options in the context of the module. Must return a `quote` block.

  If you want to persist anything in the DSL persistence layer,
  use `@persist {:key, value}`. It can be called multiple times to
  persist multiple times.
  """
  @callback handle_opts(Keyword.t()) :: Macro.t()
  @doc """
  Handle options in the context of the module, after all extensions have been processed. Must return a `quote` block.
  """
  @callback handle_before_compile(Keyword.t()) :: Macro.t()

  defmacro __using__(opts) do
    opts = Spark.OptionsHelpers.validate!(opts, @using_schema)

    their_opt_schema =
      Enum.map(opts[:single_extension_kinds], fn extension_kind ->
        {extension_kind, type: :atom, default: opts[:default_extensions][extension_kind]}
      end) ++
        Enum.map(opts[:many_extension_kinds], fn extension_kind ->
          {extension_kind, type: {:list, :atom}, default: []}
        end)

    their_opt_schema =
      if opts[:untyped_extensions?] do
        Keyword.put(their_opt_schema, :extensions, type: {:list, :atom})
      else
        their_opt_schema
      end

    their_opt_schema = Keyword.put(their_opt_schema, :otp_app, type: :atom)

    quote bind_quoted: [
            their_opt_schema: their_opt_schema,
            parent_opts: opts,
            parent: __CALLER__.module
          ],
          generated: true do
      require Spark.Dsl.Extension
      @dialyzer {:nowarn_function, handle_opts: 1, handle_before_compile: 1}
      Module.register_attribute(__MODULE__, :spark_dsl, persist: true)
      Module.register_attribute(__MODULE__, :spark_default_extensions, persist: true)
      Module.register_attribute(__MODULE__, :spark_extension_kinds, persist: true)
      @spark_dsl true
      @spark_default_extensions parent_opts[:default_extensions]
                                |> Keyword.values()
                                |> List.flatten()
      @spark_extension_kinds List.wrap(parent_opts[:many_extension_kinds]) ++
                               List.wrap(parent_opts[:single_extension_kinds])

      def init(opts), do: {:ok, opts}

      def default_extensions, do: @spark_default_extensions

      def handle_opts(opts) do
        quote do
        end
      end

      def handle_before_compile(opts) do
        quote do
        end
      end

      defoverridable init: 1, handle_opts: 1, handle_before_compile: 1

      defmacro __using__(opts) do
        parent = unquote(parent)
        parent_opts = unquote(parent_opts)
        their_opt_schema = unquote(their_opt_schema)
        require Spark.Dsl.Extension

        {opts, extensions} =
          parent_opts[:default_extensions]
          |> Enum.reduce(opts, fn {key, defaults}, opts ->
            Keyword.update(opts, key, defaults, fn current_value ->
              cond do
                key in parent_opts[:single_extension_kinds] ->
                  current_value || defaults

                key in parent_opts[:many_extension_kinds] || key == :extensions ->
                  List.wrap(current_value) ++ List.wrap(defaults)

                true ->
                  current_value
              end
            end)
          end)
          |> Spark.Dsl.expand_modules(parent_opts, __CALLER__)

        opts =
          opts
          |> Spark.OptionsHelpers.validate!(their_opt_schema)
          |> init()
          |> Spark.Dsl.unwrap()

        body =
          quote generated: true do
            parent = unquote(parent)
            opts = unquote(opts)
            parent_opts = unquote(parent_opts)
            their_opt_schema = unquote(their_opt_schema)

            @opts opts
            @before_compile Spark.Dsl
            @after_compile __MODULE__
            @spark_is parent
            @spark_parent parent

            def spark_is, do: @spark_is

            defmacro __after_compile__(_, _) do
              quote do
                transformers_to_run =
                  @extensions
                  |> Enum.flat_map(& &1.transformers())
                  |> Spark.Dsl.Transformer.sort()
                  |> Enum.filter(& &1.after_compile?())

                __MODULE__
                |> Spark.Dsl.Extension.run_transformers(
                  transformers_to_run,
                  Module.get_attribute(__MODULE__, :spark_dsl_config),
                  false,
                  __ENV__
                )
              end
            end

            Module.register_attribute(__MODULE__, :persist, accumulate: true)

            opts
            |> @spark_parent.handle_opts()
            |> Code.eval_quoted([], __ENV__)

            if opts[:otp_app] do
              @persist {:otp_app, opts[:otp_app]}
            end

            for single_extension_kind <- parent_opts[:single_extension_kinds] do
              @persist {single_extension_kind, opts[single_extension_kind]}
              Module.put_attribute(__MODULE__, single_extension_kind, opts[single_extension_kind])
            end

            for many_extension_kind <- parent_opts[:many_extension_kinds] do
              @persist {many_extension_kind, opts[many_extension_kind] || []}
              Module.put_attribute(
                __MODULE__,
                many_extension_kind,
                opts[many_extension_kind] || []
              )
            end
          end

        preparations = Spark.Dsl.Extension.prepare(extensions)
        [body | preparations]
      end
    end
  end

  @doc false
  def unwrap({:ok, value}), do: value
  def unwrap({:error, error}), do: raise(error)

  @doc false
  def expand_modules(opts, their_opt_schema, env) do
    Enum.reduce(opts, {[], []}, fn {key, value}, {opts, extensions} ->
      cond do
        key in their_opt_schema[:single_extension_kinds] ->
          mod = Macro.expand(value, env)

          extensions =
            if Spark.implements_behaviour?(mod, Spark.Dsl.Extension) do
              [mod | extensions]
            else
              extensions
            end

          {Keyword.put(opts, key, mod), extensions}

        key in their_opt_schema[:many_extension_kinds] || key == :extensions ->
          mods =
            value
            |> List.wrap()
            |> Enum.map(&Macro.expand(&1, env))

          extensions =
            extensions ++
              Enum.filter(mods, &Spark.implements_behaviour?(&1, Spark.Dsl.Extension))

          {Keyword.put(opts, key, mods), extensions}

        true ->
          {Keyword.put(opts, key, value), extensions}
      end
    end)
  end

  defmacro __before_compile__(_env) do
    quote unquote: false, generated: true do
      @type t :: __MODULE__
      require Spark.Dsl.Extension

      Module.register_attribute(__MODULE__, :spark_is, persist: true)
      Module.put_attribute(__MODULE__, :spark_is, @spark_is)

      Spark.Dsl.Extension.set_state(@persist)

      for {block, bindings} <- @spark_dsl_config[:eval] || [] do
        Code.eval_quoted(block, bindings, __ENV__)
      end

      def __spark_placeholder__, do: nil

      def spark_dsl_config do
        @spark_dsl_config
      end

      @opts
      |> @spark_parent.handle_before_compile()
      |> Code.eval_quoted([], __ENV__)
    end
  end

  def is?(module, type) when is_atom(module) do
    module.spark_is() == type
  rescue
    _ -> false
  end

  def is?(_module, _type), do: false
end
