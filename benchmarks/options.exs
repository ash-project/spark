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

Spark.Options.Validator.create(MySchema, schema, __ENV__)

# prime
Spark.Options.validate!([foo: "foo", bar: "bar", baz: 20], schema)
MySchema.validate!([foo: "foo", bar: "bar", baz: 20])

Benchee.run(
  %{
    "existing" => fn ->
      Spark.Options.validate!([foo: "foo", bar: "bar", baz: 20], schema)
    end,
    "validator" => fn ->
      MySchema.validate!([foo: "foo", bar: "bar", baz: 20])
    end
})
