defmodule Spark.Igniter do
  @moduledoc """
  Helpers for patching Spark DSLs.
  """
  require Igniter.Code.Common
  alias Sourceror.Zipper

  @doc "Sets an option at a given path within in a DSL."
  @spec set_option(
          Igniter.t(),
          spark :: module,
          Path.t(),
          dsl_path :: list(atom),
          value :: term(),
          (Zipper.t() -> {:ok, Zipper.t()} | {:error, term | list(term)} | :error)
        ) :: Igniter.t()
  def set_option(igniter, spark, file_path, path, value, updater \\ &{:ok, &1}) do
    {body, [last]} = Enum.split(List.wrap(path), -1)
    path = Enum.map(body, &{:section, &1}) ++ [{:option, last}]

    update_dsl(igniter, spark, file_path, path, value, updater)
  end

  def update_dsl(igniter, spark, file_path, path, value, func) do
    Igniter.update_elixir_file(igniter, file_path, fn zipper ->
      case Igniter.Code.Module.move_to_module_using(zipper, spark) do
        {:ok, zipper} ->
          do_update_dsl(zipper, path, value, func)

        _ ->
          {:ok, zipper}
      end
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

  def add_extension(igniter, path, type, key, extension, singleton? \\ false) do
    Igniter.update_elixir_file(igniter, path, fn zipper ->
      with {:ok, zipper} <- Igniter.Code.Module.move_to_module_using(zipper, type),
           {:ok, zipper} <- Igniter.Code.Module.move_to_use(zipper, type) do
        if Igniter.Code.Common.node_matches_pattern?(zipper, {_, _, [_]}) do
          value =
            if singleton? do
              extension
            else
              [extension]
            end

          Igniter.Code.Function.append_argument(zipper, [{key, value}])
        else
          Igniter.Code.Function.update_nth_argument(zipper, 1, fn zipper ->
            if singleton? do
              case Igniter.Code.Keyword.put_in_keyword(zipper, [key], extension, fn x ->
                     Sourceror.Zipper.replace(x, extension)
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
        end
      else
        _ ->
          {:ok, zipper}
      end
    end)
  end
end
