defmodule Spark.Formatter do
  @moduledoc """
  Formats Spark modules.

  Currently, it is very simple, and will only reorder the outermost sections according to some rules.

  # Plugin

  Include the plugin into your `.formatter.exs` like so `plugins: [Spark.Formatter]`.

  If no configuration is provided, it will sort all top level DSL sections *alphabetically*.

  # Section Order

  To provide a custom section order, add configuration to your app, for example:

  ```elixir
  config :spark, :formatter,
    "Ash.Resource": [
      section_order: [
        :resource,
        :postgres,
        :attributes,
        :relationships,
        :aggregates,
        :calculations
      ]
    ],
    "MyApp.Resource": [
      # Use this if you use a module that is not the spark DSL itself.
      # For example, you might have a "base" that you use instead that sets some simple defaults.
      # This tells us what the actual thing is so we know what extensions are included automatically.
      type: Ash.Resource,
      # Tell us what extensions might be added under the hood
      extensions: [MyApp.ResourceExtension],
      section_order: [...]
    ]
  ```

  Any sections found that aren't in that list will be left in the order that they were in, the sections
  in the list will be sorted "around" those sections. E.g the following list: `[:code_interface, :attributes]` can be interpreted as
  "ensure that code_interface comes before attributes, and don't change the rest".
  """
  @behaviour Mix.Tasks.Format

  require Logger

  def features(_opts) do
    [extensions: [".ex", ".exs"]]
  end

  def format(contents, opts) do
    config =
      :spark
      |> Application.get_env(:formatter, [])
      |> Enum.map(fn {key, value} ->
        {Code.ensure_compiled!(Module.concat([key])), value}
      end)

    parse_result =
      try do
        {:ok, Sourceror.parse_string!(contents)}
      rescue
        _ ->
          :error
      end

    case parse_result do
      {:ok, parsed} ->
        parsed
        |> format_resources(opts, config)
        |> then(fn patches ->
          Sourceror.patch_string(contents, patches)
        end)
        |> Code.format_string!(opts_without_plugin(opts))
        |> then(fn iodata ->
          [iodata, ?\n]
        end)
        |> IO.iodata_to_binary()

      :error ->
        contents
    end
  end

  defp format_resources(parsed, opts, config) do
    {_, patches} =
      prewalk(parsed, [], false, fn
        {:defmodule, _, [_, [{{:__block__, _, [:do]}, {:__block__, _, body}}]]} = expr,
        patches,
        false ->
          case get_extensions(body, config) do
            {:ok, extensions, type} ->
              replacement = format_resource(body, extensions, config, type)

              patches =
                body
                |> Enum.zip(replacement)
                |> Enum.reduce(patches, fn {body_section, replacement_section}, patches ->
                  if body_section == replacement_section do
                    patches
                  else
                    [
                      %{
                        range: Sourceror.get_range(body_section, include_comments: true),
                        change: Sourceror.to_string(replacement_section, opts)
                      }
                      | patches
                    ]
                  end
                end)

              {expr, patches, true}

            _ ->
              {expr, patches, true}
          end

        expr, patches, branch_acc ->
          {expr, patches, branch_acc}
      end)

    patches
  end

  @doc """
  Copy of `Macro.prewalk/2` w/ a branch accumulator
  """
  def prewalk(ast, fun) when is_function(fun, 1) do
    elem(prewalk(ast, nil, nil, fn x, nil, nil -> {fun.(x), nil} end), 0)
  end

  @doc """
  Copy of `Macro.prewalk/3` w/ a branch accumulator
  """
  def prewalk(ast, acc, branch_acc, fun) when is_function(fun, 3) do
    traverse(ast, acc, branch_acc, fun, fn x, a -> {x, a} end)
  end

  @doc """
  A copy of the corresponding `Macro.traverse` function that has a separate accumulator that only goes *down* each branch, only for `pre`
  """
  def traverse(ast, acc, branch_acc, pre, post)
      when is_function(pre, 3) and is_function(post, 2) do
    {ast, acc, branch_acc} = pre.(ast, acc, branch_acc)
    do_traverse(ast, acc, branch_acc, pre, post)
  end

  defp do_traverse({form, meta, args}, acc, branch_acc, pre, post) when is_atom(form) do
    {args, acc} = do_traverse_args(args, acc, branch_acc, pre, post)
    post.({form, meta, args}, acc)
  end

  defp do_traverse({form, meta, args}, acc, branch_acc, pre, post) do
    {form, acc, branch_acc} = pre.(form, acc, branch_acc)
    {form, acc} = do_traverse(form, acc, branch_acc, pre, post)
    {args, acc} = do_traverse_args(args, acc, branch_acc, pre, post)
    post.({form, meta, args}, acc)
  end

  defp do_traverse({left, right}, acc, branch_acc, pre, post) do
    {left, acc, left_branch_acc} = pre.(left, acc, branch_acc)
    {left, acc} = do_traverse(left, acc, left_branch_acc, pre, post)
    {right, acc, right_branch_acc} = pre.(right, acc, branch_acc)
    {right, acc} = do_traverse(right, acc, right_branch_acc, pre, post)
    post.({left, right}, acc)
  end

  defp do_traverse(list, acc, branch_acc, pre, post) when is_list(list) do
    {list, acc} = do_traverse_args(list, acc, branch_acc, pre, post)
    post.(list, acc)
  end

  defp do_traverse(x, acc, _branch_acc, _pre, post) do
    post.(x, acc)
  end

  defp do_traverse_args(args, acc, _branch_acc, _pre, _post) when is_atom(args) do
    {args, acc}
  end

  defp do_traverse_args(args, acc, branch_acc, pre, post) when is_list(args) do
    :lists.mapfoldl(
      fn x, acc ->
        {x, acc, branch_acc} = pre.(x, acc, branch_acc)
        do_traverse(x, acc, branch_acc, pre, post)
      end,
      acc,
      args
    )
  end

  defp format_resource(body, extensions, config, type) do
    sections =
      extensions
      |> Enum.flat_map(fn extension ->
        Enum.map(extension.sections(), fn section ->
          {extension, section}
        end)
      end)
      |> sort_sections(config[type][:section_order])

    section_names = Enum.map(sections, fn {_, section} -> section.name end)

    {section_exprs, non_section_exprs} =
      body
      |> Enum.split_with(fn {name, _, _} ->
        name in section_names
      end)

    new_sections =
      section_names
      |> Enum.flat_map(fn section_name ->
        matching_section =
          Enum.find(section_exprs, fn
            {^section_name, _, _} -> true
            _ -> nil
          end)

        case matching_section do
          nil ->
            []

          section_expr ->
            [section_expr]
        end
      end)

    Enum.concat(non_section_exprs, new_sections)
  end

  defp sort_sections(sections, nil), do: sections

  defp sort_sections(sections, section_order) do
    {ordered, unordered} =
      sections
      |> Enum.with_index()
      |> Enum.split_with(fn {{_, section}, _} ->
        section.name in section_order
      end)

    reordered =
      ordered
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort_by(fn {_, section} ->
        Enum.find_index(section_order, &(&1 == section.name))
      end)

    Enum.reduce(unordered, reordered, fn {{extension, section}, i}, acc ->
      List.insert_at(acc, i, {extension, section})
    end)
  end

  defp get_extensions(body, config) do
    Enum.find_value(body, :error, fn
      {:use, _, using} ->
        [using, opts] =
          case Spark.Dsl.Extension.expand_alias(using, __ENV__) do
            [using] ->
              [using, []]

            [using, opts] ->
              [using, opts]
          end

        if Keyword.has_key?(config, using) do
          {:ok, parse_extensions(opts, config, using), using}
        end

      _ ->
        nil
    end)
  end

  defp parse_extensions(blocks, config, type) do
    blocks
    |> Enum.flat_map(fn {{:__block__, _, _}, extensions} ->
      extensions
      |> case do
        {:__block__, _, [extensions]} ->
          extensions

        extension when is_atom(extension) ->
          extension

        _ ->
          []
      end
      |> List.wrap()
      |> Enum.flat_map(fn extension ->
        case Code.ensure_compiled(extension) do
          {:module, module} ->
            if Spark.implements_behaviour?(module, Spark.Dsl.Extension) do
              [module]
            else
              []
            end

          _ ->
            []
        end
      end)
    end)
    |> Enum.concat(config[:extensions] || [])
    |> Enum.concat(type.default_extensions() || [])
  end

  defp opts_without_plugin(opts) do
    Keyword.update(opts, :plugins, [], &(&1 -- [__MODULE__]))
  end
end
