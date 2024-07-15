defmodule Spark.Igniter do
  @moduledoc """
  Helpers for patching Spark DSLs.
  """
  require Igniter.Code.Common
  alias Sourceror.Zipper

  @doc "Prepends a new section or list of sections to the section order in a formatter configuration."
  def prepend_to_section_order(igniter, type, sections) do
    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      :spark,
      [:formatter, type, :section_order],
      sections,
      updater: fn zipper ->
        sections
        |> List.wrap()
        |> Enum.reverse()
        |> Enum.reduce({:ok, zipper}, fn section, {:ok, zipper} ->
          case Igniter.Code.List.prepend_new_to_list(zipper, section) do
            {:ok, zipper} -> {:ok, zipper}
            :error -> {:ok, zipper}
          end
        end)
      end
    )
  end

  @doc "Sets an option at a given path within in a DSL."
  @spec set_option(
          Igniter.t(),
          module,
          dsl_path :: list(atom),
          value :: term(),
          (Zipper.t() -> {:ok, Zipper.t()} | {:error, term | list(term)} | :error)
        ) :: Igniter.t()
  def set_option(igniter, module, path, value, updater \\ &{:ok, &1}) do
    {body, [last]} = Enum.split(List.wrap(path), -1)
    path = Enum.map(body, &{:section, &1}) ++ [{:option, last}]

    update_dsl(igniter, module, path, value, updater)
  end

  def update_dsl(igniter, module, path, value, func) do
    Igniter.Code.Module.find_and_update_module!(igniter, module, fn zipper ->
      do_update_dsl(zipper, path, value, func)
    end)
  end

  defp do_update_dsl(zipper, [], value, fun) do
    if Igniter.Code.Common.node_matches_pattern?(zipper, v when is_nil(v)) do
      {:ok, Sourceror.Zipper.replace(zipper, value)}
    else
      fun.(zipper)
    end
  end

  defp do_update_dsl(zipper, [{:section, name} | rest], value, fun) do
    with {:ok, zipper} <-
           Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, name, 1),
         {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper) do
      do_update_dsl(zipper, rest, value, fun)
    else
      _ ->
        zipper =
          Igniter.Code.Common.add_code(zipper, """
          #{name} do
          end
          """)

        with {:ok, zipper} <-
               Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, name, 1),
             {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper) do
          do_update_dsl(zipper, rest, value, fun)
        else
          _ ->
            {:ok, zipper}
        end
    end
  end

  defp do_update_dsl(zipper, [{:option, name}], value, fun) do
    case Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, name, 1) do
      {:ok, zipper} ->
        Igniter.Code.Function.update_nth_argument(zipper, 0, fun)

      _ ->
        added_zipper = Igniter.Code.Common.add_code(zipper, {name, [], [value]})

        case Igniter.Code.Function.move_to_function_call_in_current_scope(added_zipper, name, 1) do
          {:ok, zipper} ->
            {:ok, zipper}

          _ ->
            {:ok, zipper}
        end
    end
  end

  defp do_update_dsl(_zipper, [{:option, name} | _], _value, _fun) do
    raise ArgumentError,
          "{:option, #{inspect(name)}} was found as a non-leaf node in a path to update. Options must be the last item in the list."
  end

  def remove_extension(igniter, module, type, key, extension, singleton? \\ false) do
    Igniter.Code.Module.find_and_update_module!(igniter, module, fn zipper ->
      with {:ok, zipper} <- Igniter.Code.Module.move_to_use(zipper, type) do
        if Igniter.Code.Common.node_matches_pattern?(zipper, {_, _, [_]}) do
          :error
        else
          if singleton? do
            case Igniter.Code.Keyword.remove_keyword_key(zipper, key) do
              {:ok, zipper} ->
                {:ok, zipper}

              _ ->
                :error
            end
          else
            Igniter.Code.Keyword.put_in_keyword(zipper, [key], [], fn zipper ->
              Igniter.Code.List.remove_from_list(zipper, fn nested_zipper ->
                Igniter.Code.Common.nodes_equal?(nested_zipper, extension)
              end)
            end)
          end
        end
      end
      |> case do
        :error ->
          {:ok, zipper}

        {:ok, zipper} ->
          do_remove_constructors(zipper, type, extension)
      end
    end)
  end

  defp do_remove_constructors(zipper, type, extension) do
    constructors_to_remove = extension_constructors(extension)

    zipper = Zipper.topmost(zipper)
    {:ok, zipper} = Igniter.Code.Module.move_to_module_using(zipper, type)

    remove_constructors(zipper, constructors_to_remove)
  end

  # sobelow_skip ["DOS.StringToAtom"]
  def add_extension(igniter, module, type, key, extension, singleton? \\ false) do
    extension = {:__aliases__, [], Enum.map(Module.split(extension), &String.to_atom/1)}

    Igniter.Code.Module.find_and_update_module!(igniter, module, fn zipper ->
      case Igniter.Code.Module.move_to_use(zipper, type) do
        {:ok, zipper} ->
          if Igniter.Code.Common.node_matches_pattern?(zipper, {_, _, [_]}) do
            value =
              if singleton? do
                extension
              else
                [extension]
              end

            Igniter.Code.Function.append_argument(zipper, [{key, value}])
          else
            remove_extension =
              if singleton? do
                with {:ok, arg_zipper} <- Igniter.Code.Function.move_to_nth_argument(zipper, 1),
                     {:ok, value_zipper} <- Igniter.Code.Keyword.get_key(arg_zipper, key),
                     module_zipper <- Igniter.Code.Common.expand_aliases(value_zipper),
                     {:__aliases__, _, parts} <- Zipper.node(module_zipper) do
                  {:ok, Module.concat(parts)}
                else
                  _ ->
                    :error
                end
              else
                :error
              end

            Igniter.Code.Function.update_nth_argument(zipper, 1, fn zipper ->
              if singleton? do
                case Igniter.Code.Keyword.put_in_keyword(zipper, [key], extension, fn x ->
                       {:ok, Igniter.Code.Common.replace_code(x, extension)}
                     end) do
                  {:ok, zipper} ->
                    {:ok, zipper}

                  _ ->
                    {:ok, zipper}
                end
              else
                Igniter.Code.Keyword.put_in_keyword(zipper, [key], [extension], fn zipper ->
                  Igniter.Code.List.prepend_new_to_list(
                    zipper,
                    extension
                  )
                end)
              end
            end)
            |> case do
              {:ok, zipper} ->
                case remove_extension do
                  {:ok, module} ->
                    if Code.ensure_loaded?(module) &&
                         Spark.implements_behaviour?(module, Spark.Dsl.Extension) do
                      do_remove_constructors(zipper, type, module)
                    else
                      {:ok, zipper}
                    end

                  :error ->
                    {:ok, zipper}
                end

              :error ->
                :error
            end
          end

        _ ->
          {:ok, zipper}
      end
    end)
  end

  defp remove_constructors(zipper, []), do: {:ok, zipper}

  defp remove_constructors(zipper, [{name, arity} | rest] = all) do
    Igniter.Code.Common.within(zipper, fn zipper ->
      case Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, name, arity) do
        {:ok, zipper} ->
          {:ok, Zipper.remove(zipper)}

        :error ->
          :error
      end
    end)
    |> case do
      :error ->
        remove_constructors(zipper, rest)

      {:ok, zipper} ->
        remove_constructors(zipper, all)
    end
  end

  defp extension_constructors(module) do
    module.sections()
    |> Enum.flat_map(fn section ->
      if section.top_level? do
        nested_entities =
          Enum.flat_map(section.entities, fn entity ->
            total_count = Enum.count(entity.args)
            optional_count = Enum.count(entity.args, &(not is_atom(&1)))

            required_count = total_count - optional_count

            Enum.map(required_count..total_count, fn i ->
              {entity.name, i}
            end)
          end)

        nested_sections =
          Enum.map(section.sections, fn section ->
            {section.name, 1}
          end)

        nested_entities ++ nested_sections
      else
        [{section.name, 1}]
      end
    end)
  end
end
