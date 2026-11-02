# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

# Measures how long a DSL extension, and a module using it, take to compile, and how
# large the generated modules are. Run with:
#
#     mix run benchmarks/compile_dsl.exs
#
# ENTITIES, SECTIONS (nested sections), OPTIONS and RUNS environment variables override the
# defaults. The generated DSL usage sets opt_1 everywhere and opt_2 in entities, so OPTIONS
# must be at least 1, or at least 2 when ENTITIES is above 0.

entities = String.to_integer(System.get_env("ENTITIES", "40"))
sections = String.to_integer(System.get_env("SECTIONS", "10"))
options = String.to_integer(System.get_env("OPTIONS", "15"))
runs = String.to_integer(System.get_env("RUNS", "5"))

if runs < 1 do
  raise ArgumentError, "RUNS must be at least 1"
end

if options < 1 or (entities > 0 and options < 2) do
  raise ArgumentError, "OPTIONS must be at least 1, or at least 2 when ENTITIES is above 0"
end

source = fn prefix ->
  schema =
    for o <- 1..options//1 do
      ~s|opt_#{o}: [type: {:or, [:atom, :string, {:fun, 1}]}, doc: "Option #{o}."]|
    end

  entity_defs =
    for e <- 1..entities//1 do
      """
      %Spark.Dsl.Entity{
        name: :entity_#{e},
        target: #{prefix}.Target,
        args: [:name],
        identifier: :name,
        describe: "Entity #{e}.",
        schema: [name: [type: :atom, required: true], #{Enum.join(schema, ", ")}],
        entities: [children: [%Spark.Dsl.Entity{name: :child, target: #{prefix}.Target, args: [:name], schema: [name: [type: :atom], #{Enum.join(schema, ", ")}]}]]
      }
      """
    end

  section_defs =
    for s <- 1..sections//1 do
      ~s|%Spark.Dsl.Section{name: :section_#{s}, schema: [#{Enum.join(schema, ", ")}]}|
    end

  section_usages =
    for s <- 1..sections//1 do
      """
      section_#{s} do
        opt_1 :a
      end
      """
    end

  usages =
    for e <- 1..entities//1 do
      """
      entity_#{e} :e#{e} do
        opt_1 :a
        opt_2 "b"

        child :c do
          opt_1 &Function.identity/1
        end
      end
      """
    end

  """
  defmodule #{prefix}.Target do
    defstruct [:name, :children, :__identifier__, :__spark_metadata__] ++
                Enum.map(1..#{options}//1, &:"opt_\#{&1}")
  end

  defmodule #{prefix}.Extension do
    use Spark.Dsl.Extension,
      sections: [
        %Spark.Dsl.Section{
          name: :items,
          schema: [#{Enum.join(schema, ", ")}],
          entities: [#{Enum.map_join(entity_defs, ",\n", &String.trim/1)}],
          sections: [#{Enum.join(section_defs, ",\n")}]
        }
      ]
  end

  defmodule #{prefix}.Dsl do
    use Spark.Dsl, default_extensions: [extensions: [#{prefix}.Extension]]
  end

  defmodule #{prefix}.User do
    use #{prefix}.Dsl

    items do
      opt_1 :a
      #{Enum.join(usages, "\n")}
      #{Enum.join(section_usages, "\n")}
    end
  end
  """
end

results =
  for run <- 1..runs//1 do
    dir = Path.join(System.tmp_dir!(), "spark_compile_dsl_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    file = Path.join(dir, "bench.ex")
    File.write!(file, source.("SparkCompileBench.Run#{run}"))

    {micros, {:ok, modules, _warnings}} =
      :timer.tc(fn ->
        Kernel.ParallelCompiler.compile_to_path([file], dir, return_diagnostics: true)
      end)

    bytes =
      dir
      |> Path.join("*.beam")
      |> Path.wildcard()
      |> Enum.map(&File.stat!(&1).size)
      |> Enum.sum()

    Enum.each(modules, fn module ->
      :code.purge(module)
      :code.delete(module)
    end)

    File.rm_rf!(dir)
    {micros / 1000, length(modules), bytes}
  end

times = results |> Enum.map(&elem(&1, 0)) |> Enum.sort()
{_, module_count, bytes} = hd(results)
middle = div(runs, 2)

median =
  if rem(runs, 2) == 1 do
    Enum.at(times, middle)
  else
    (Enum.at(times, middle - 1) + Enum.at(times, middle)) / 2
  end

IO.puts("""
#{entities} entities, #{sections} nested sections x #{options} options, #{runs} runs
compile time: median #{Float.round(median, 0)} ms, min #{Float.round(hd(times), 0)} ms
generated: #{module_count} modules, #{Float.round(bytes / 1024, 1)} KiB of BEAM
""")
