defmodule Spark.Options.Validator do
  @moduledoc """
  Defines a validator module for an option schema.

  Validators create structs with keys for each option in their schema,
  and an optimized `validate`, and `validate!` function on that struct.

  ## Upgrading from options lists

  You can pass the option `define_deprecated_access?: true` to `use Spark.Options.Validator`,
  which will make it such that `options[:foo]` will still work, but will emit a deprecation warning.
  This cane help with smoother upgrades.

  ## Example

  Given a module like the following:

  ```elixir
  defmodule MyOptions do
    use Spark.Options.Validator, schema: [
      foo: [
        type: :string,
        required: true
      ],
      bar: [
        type: :string
      ],
      baz: [
        type: :integer,
        default: 10
      ]
    ]
  end
  ```

  You can use it like so:

  ```elixir
  # validate options

  MyOptions.validate!(foo: "foo")
  # %MyOptions{foo: "foo", bar: nil, baz: 10}

  # retrieve original schema
  MyOptions.schema()
  # foo: [type: :string, required: true], bar: [type: :string], baz: [type: :integer, default: 10]
  ```
  """

  defmacro __using__(opts) do
    schema = opts[:schema]
    define_deprecated_access? = opts[:define_deprecated_access?]

    [
      quote do
        @schema unquote(schema)

        struct_fields =
          Keyword.new(@schema, fn {key, config} ->
            {key, config[:default]}
          end)

        defstruct struct_fields

        quote do
          @type t :: %__MODULE__{unquote_splicing(Spark.Options.Docs.schema_specs(@schema))}
        end
        |> Code.eval_quoted([], __ENV__)

        required_fields =
          Spark.Options.Validator.validate_schema!(@schema)

        @required @schema
                  |> Enum.filter(fn {_key, config} ->
                    config[:required]
                  end)
                  |> Enum.map(&elem(&1, 0))

        @type schema :: Spark.Options.t()
        def schema do
          @schema
        end

        if unquote(define_deprecated_access?) do
          def fetch(%__MODULE__{} = data, key) do
            IO.warn(
              "Accessing options from #{__MODULE__} is deprecated. Use `opts.#{key}` instead."
            )

            Map.fetch(data, key)
          end
        end

        @spec validate!(Keyword.t()) :: t() | no_return
        def validate!(options) do
          Enum.reduce(options, {%__MODULE__{}, @required}, fn {key, value}, acc ->
            case validate_option(key, value, acc) do
              {:cont, acc} -> acc
              {:halt, {:error, error}} -> raise error
            end
          end)
          |> case do
            {schema, []} -> schema
            {schema, missing} -> raise "Missing required keys: #{inspect(missing)}"
          end
        end

        @spec validate(Keyword.t()) :: {:ok, t()} | {:error, term()}
        def validate(options) do
          Enum.reduce_while(options, {%__MODULE__{}, @required}, fn {key, value}, acc ->
            validate_option(key, value, acc)
          end)
          |> case do
            {schema, []} -> {:ok, schema}
            {schema, missing} -> {:error, "Missing required keys: #{inspect(missing)}"}
          end
        end
      end,
      quote bind_quoted: [schema: schema] do
        for {key, config} <- schema do
          type = config[:type]

          cond do
            # we can add as many of these as we like to front load validations
            type == :integer ->
              def validate_option(unquote(key), value, {acc, required_fields})
                  when is_integer(value) do
                {:cont, {%{acc | unquote(key) => value}, use_key(required_fields, unquote(key))}}
              end

              def validate_option(unquote(key), value, _) do
                {:halt,
                 {:error,
                  %Spark.Options.ValidationError{
                    key: unquote(key),
                    message:
                      "invalid value for #{Spark.Options.render_key(unquote(key))}: expected integer, got: #{inspect(value)}",
                    value: value
                  }}}
              end

            type == :string ->
              def validate_option(unquote(key), value, {acc, required_fields})
                  when is_binary(value) do
                {:cont, {%{acc | unquote(key) => value}, use_key(required_fields, unquote(key))}}
              end

              def validate_option(unquote(key), value, _) do
                {:halt,
                 {:error,
                  %Spark.Options.ValidationError{
                    key: unquote(key),
                    message:
                      "invalid value for #{Spark.Options.render_key(unquote(key))}: expected integer, got: #{inspect(value)}",
                    value: value
                  }}}
              end

            true ->
              def validate_option(unquote(key), value, {acc, required_fields}) do
                case Spark.Options.validate_single_value(unquote(type), unquote(key), value) do
                  {:ok, value} ->
                    {:cont, {%{acc | unquote(key) => value},
                     use_key(required_fields, unquote(key))}}

                  {:error, error} ->
                    {:halt, {:error, error}}
                end
              end
          end
        end

        def validate_option(unknown_key, value, _) do
          {:halt, {:error, "Unknown key #{unknown_key}"}}
        end

        for {key, config} <- schema do
          if config[:required] do
            defp use_key(list, unquote(key)) do
              warn_deprecated(unquote(key))
              List.delete(list, unquote(key))
            end
          else
            defp use_key(list, unquote(key)) do
              warn_deprecated(unquote(key))

              list
            end
          end
        end

        for {key, config} <- schema, config[:deprecated] do
          defp warn_deprecated(unquote(key)) do
            IO.warn("#{unquote(key)} is deprecated")
          end
        end

        defp warn_deprecated(_key) do
          :ok
        end
      end
    ]
  end

  @doc false
  def validate_schema!(schema) do
    if schema[:*] do
      raise "Schema with * not supported in validator"
    else
      Enum.each(schema, fn {_key, config} ->
        if config[:type] == :keyword do
          # When we support nested keywords, they should get structs
          # auto defined for them as well.
          raise "Nested keywords not accepted in validators yet"
        end
      end)
    end
  end
end
