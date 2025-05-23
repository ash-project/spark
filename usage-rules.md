# Rules for working with Spark

## Overview

Spark is a framework for building Domain-Specific Languages (DSLs) in Elixir. It enables developers to create declarative DSLs with minimal boilerplate.

### Key Characteristics
- **Purpose**: Build extensible, validated DSLs with compile-time processing
- **Version**: This guide covers v2.2.60
- **Dependencies**: `nimble_options` for validation, `sourceror` for code manipulation
- **Philosophy**: Declarative over imperative, extensibility-first design

## Core Architecture

### 1. Entity-Section-Extension Model

Spark DSLs are built using three core components:

```elixir
# 1. Entities - Individual DSL constructors
@field %Spark.Dsl.Entity{
  name: :field,                    # DSL function name
  target: MyApp.Field,            # Struct to build
  args: [:name, :type],           # Positional arguments
  schema: [                       # Validation schema
    name: [type: :atom, required: true],
    type: [type: :atom, required: true]
  ]
}

# 2. Sections - Organize related entities
@fields %Spark.Dsl.Section{
  name: :fields,
  entities: [@field],             # Contains entities
  sections: [],                   # Can nest sections
  schema: [                       # Section-level options
    required: [type: {:list, :atom}, default: []]
  ]
}

# 3. Extensions - Package DSL functionality
defmodule MyExtension do
  use Spark.Dsl.Extension,
    sections: [@fields],
    transformers: [MyTransformer],
    verifiers: [MyVerifier]
end
```

### 2. Compile-Time Processing Pipeline

```
DSL Definition → Parsing → Validation → Transformation → Verification → Code Generation
```

1. **Parsing**: DSL syntax converted to internal representation
2. **Validation**: Schema validation via `Spark.Options`
3. **Transformation**: Transformers modify DSL state
4. **Verification**: Verifiers validate final state
5. **Code Generation**: Generate runtime modules/functions

## Creating a DSL with Spark

### Basic DSL Structure

```elixir
# Step 1: Define your extension
defmodule MyLibrary.Dsl do
  @my_nested_entity %Spark.Dsl.Entity{
    name: :my_nested_entity,
    target: MyLibrary.MyNestedEntity,
    describe: """
    Describe the entity.
    """,
    examples: [
      "my_nested_entity :name, option: \"something\"",
      """
      my_nested_entity :name do
        option "something"
      end
      """
    ],
    args: [:name],
    schema: [
      name: [type: :atom, required: true, doc: "The name of the entity"],
      option: [type: :string, default: "default", doc: "An option that does X"]
    ]
  }

  @my_entity %Spark.Dsl.Entity{
    name: :my_entity,
    target: MyLibrary.MyEntity,
    args: [:name],
    entities: [
      entities: [@my_nested_entity]
    ],
   describe: ...,
    examples: [...],
    schema: [
      name: [type: :atom, required: true, doc: "The name of the entity"],
      option: [type: :string, default: "default", doc: "An option that does X"]
    ]
  }
  
  @my_section %Spark.Dsl.Section{
    name: :my_section,
    describe: ...,
    examples: [...],
    schema: [
      section_option: [type: :string]
    ],
    entities: [@my_entity]
  }
  
  use Spark.Dsl.Extension, sections: [@my_section]
end

# Entity Targets
defmodule MyLibrary.MyEntity do
  defstruct [:name, :option, :entities]
end

defmodule MyLibrary.MyNestedEntity do
  defstruct [:name, :option]
end

# Step 2: Create the DSL module
defmodule MyLibrary do
  use Spark.Dsl, 
    default_extensions: [
      extensions: [MyLibrary.Dsl]
    ]
end

# Step 3: Use the DSL
defmodule MyApp.Example do
  use MyLibrary
  
  my_section do
    my_entity :example_name do
      option "custom value"
      my_nested_entity :nested_name do
        option "nested custom value"
      end
    end
  end
end
```

### Working with Transformers

Transformers modify the DSL at compile time:

```elixir
defmodule MyLibrary.Transformers.AddDefaults do
  use Spark.Dsl.Transformer
  
  def transform(dsl_state) do
    # Add a default entity if none exist
    entities = Spark.Dsl.Extension.get_entities(dsl_state, [:my_section])
    
    if Enum.empty?(entities) do
      {:ok, 
       Spark.Dsl.Transformer.add_entity(
         dsl_state,
         [:my_section],
         %MyLibrary.MyEntity{name: :default}
       )}
    else
      {:ok, dsl_state}
    end
  end
  
  # Control execution order
  def after?(_), do: false
  def before?(OtherTransformer), do: true
  def before?(_), do: false
end
```

### Creating Verifiers

Verifiers validate the final DSL state:

```elixir
defmodule MyLibrary.Verifiers.UniqueNames do
  use Spark.Dsl.Verifier
  
  def verify(dsl_state) do
    entities = Spark.Dsl.Extension.get_entities(dsl_state, [:my_section])
    names = Enum.map(entities, & &1.name)
    
    if length(names) == length(Enum.uniq(names)) do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(,
         message: "Entity names must be unique",
         path: [:my_section],
         module: Spark.Dsl.Verifier.get_persisted(dsl_state, :module)
       )}
    end
  end
end
```

## Common Patterns

### 1. Extension Composition

```elixir
defmodule MyApp.Resource do
  use Spark.Dsl,
    single_extension_kinds: [:data_layer],
    many_extension_kinds: [:notifiers],
    default_extensions: [
      extensions: [
        MyApp.Resource.Dsl,
        AnotherExtension
      ]
    ]
end
```

### 2. Info Module Generation

```elixir
defmodule MyLibrary.Info do
  use Spark.InfoGenerator,
    extension: MyLibrary.Dsl,
    sections: [:my_section]
end

# Generates functions like:
# MyLibrary.Info.my_section_entities(module)
# MyLibrary.Info.my_section_option!(module, :option_name)
```

## Key APIs for Claude-code

### Essential Functions

```elixir
# Get entities from a section
entities = Spark.Dsl.Extension.get_entities(dsl_state, [:section_path])

# Get section options
option = Spark.Dsl.Extension.get_opt(dsl_state, [:section_path], :option_name, default_value)

# Add entities during transformation
dsl_state = Spark.Dsl.Transformer.add_entity(dsl_state, [:section_path], entity)

# Persist data across transformers
dsl_state = Spark.Dsl.Transformer.persist(dsl_state, :key, value)
value = Spark.Dsl.Transformer.get_persisted(dsl_state, :key)

# Get current module being compiled
module = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)
```

### Schema Definition with Spark.Options

```elixir
schema = [
  required_field: [
    type: :atom,
    required: true,
    doc: "Documentation for the field"
  ],
  optional_field: [
    type: {:list, :string},
    default: [],
    doc: "Optional field with default"
  ],
  complex_field: [
    type: {:or, [:atom, :string, {:struct, MyStruct}]},
    required: false
  ]
]
```

## Important Implementation Details

### 1. Compile-Time vs Runtime

- **DSL processing happens at compile time**
- Transformers and verifiers run during compilation
- Generated code is optimized for runtime performance
- Use `persist/3` to cache expensive computations

### 2. Error Handling

Always provide context in errors:
```elixir
{:error,
 Spark.Error.DslError.exception(
   message: "Clear error message",
   path: [:section, :subsection],  # DSL path
   module: module                   # Module being compiled
 )}
```

## Common Gotchas

### 1. Compilation Deadlocks
```elixir
# WRONG - Causes deadlock
def transform(dsl_state) do
  module = get_persisted(dsl_state, :module)
  module.some_function()  # Module isn't compiled yet!
end

# RIGHT - Use DSL state
def transform(dsl_state) do
  entities = get_entities(dsl_state, [:section])
  # Work with DSL state, not module functions
end
```

### 2. Extension Order
- Extensions are processed in order
- Later extensions can modify earlier ones
- Use transformer ordering for dependencies

## Performance Considerations

1. **Compilation Performance**
   - Heavy transformers slow compilation
   - Cache expensive computations with `persist/3`
   - Use verifiers instead of transformers when possible

2. **Runtime Performance**
   - DSL processing has zero runtime overhead
   - Generated code is optimized
   - Info modules cache DSL data efficiently

3. **Memory Usage**
   - DSL state is cleaned up after compilation
   - Runtime footprint is minimal
   - Use structs efficiently in entities

## Summary

Spark enables:
- Clean, declarative DSL syntax
- Compile-time validation and transformation
- Extensible architecture
- Excellent developer experience

When coding with Spark:
1. Think in terms of entities, sections, and extensions
2. Leverage compile-time processing for validation
3. Use transformers for complex logic
4. Test DSLs thoroughly
5. Provide clear error messages
6. Document your DSLs well

