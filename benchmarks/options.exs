schema = [
  foo: [
    type: :string,
    required: true
  ],
  bar: [
    type: :string,
    default: "default"
  ],
  baz: [
    type: :integer,
    default: 10
  ]
]

new_schema = Spark.Options.new!(schema)

defmodule MySchema do
  use Spark.Options.Validator, schema: schema
end

# prime
Spark.Options.validate!([foo: "foo", bar: "bar", baz: 20], schema)
Spark.Options.validate!([foo: "foo", bar: "bar", baz: 20], new_schema)
MySchema.validate!([foo: "foo", bar: "bar", baz: 20])

Benchee.run(
  %{
    "existing" => fn ->
      options = Spark.Options.validate!([foo: "foo", bar: "bar", baz: 20], schema)
      _foo = options[:foo]
      _bar = options[:bar]
      _foo = options[:foo]
      _bar = options[:bar]
      _foo = options[:foo]
      _bar = options[:bar]
    end,
    "existing with built schema" => fn ->
      options = Spark.Options.validate!([foo: "foo", bar: "bar", baz: 20], new_schema)

      _foo = options[:foo]
      _bar = options[:bar]
      _foo = options[:foo]
      _bar = options[:bar]
      _foo = options[:foo]
      _bar = options[:bar]
    end,
    "validator" => fn ->
      %MySchema{} = options = MySchema.validate!([foo: "foo", bar: "bar", baz: 20])
      _foo = options.foo
      _bar = options.bar
      _foo = options.foo
      _bar = options.bar
      _foo = options.foo
      _bar = options.bar
    end,
    "validator to options" => fn ->
      options = MySchema.validate!([foo: "foo", bar: "bar", baz: 20]) |> MySchema.to_options()

      _foo = options[:foo]
      _bar = options[:bar]
      _foo = options[:foo]
      _bar = options[:bar]
      _foo = options[:foo]
      _bar = options[:bar]
      _foo = options[:foo]
      _bar = options[:bar]
    end
})
