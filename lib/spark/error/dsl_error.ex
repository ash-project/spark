defmodule Spark.Error.DslError do
  @moduledoc "Used when a DSL is incorrectly configured."
  @attrs [:module, :message, :path, :stacktrace]
  defexception @attrs

  @type t :: %__MODULE__{
          __exception__: true,
          module: nil | module,
          message: String.t() | any,
          path: [:atom],
          stacktrace: any
        }

  defmodule Stacktrace do
    @moduledoc false
    defstruct [:stacktrace]

    defimpl Inspect do
      def inspect(_, _) do
        "%Stacktrace{}"
      end
    end
  end

  @impl true
  def exception(message) when is_binary(message), do: exception(message: message)

  def exception(opts) do
    {:current_stacktrace, stacktrace} =
      Process.info(self(), :current_stacktrace)

    opts =
      opts
      |> Enum.to_list()
      |> Keyword.put(:stacktrace, %Stacktrace{stacktrace: stacktrace})
      |> Keyword.take(@attrs)

    struct!(__MODULE__, opts)
  end

  @impl true
  def message(%{module: module, message: message, path: blank})
      when is_nil(blank) or blank == [] do
    "#{module_line(module)}#{get_message(message)}"
  end

  def message(%{module: module, message: message, path: dsl_path}) do
    dsl_path =
      Enum.map_join(dsl_path, " -> ", fn item ->
        try do
          to_string(item)
        rescue
          _ ->
            inspect(item)
        end
      end)

    "#{module_line(module)}#{dsl_path}:\n  #{get_message(message)}"
  end

  defp get_message(message) when is_exception(message) do
    Exception.format(:error, message)
  end

  defp get_message(message) when is_binary(message) do
    message
  end

  defp get_message(message) do
    inspect(message)
  end

  defp module_line(nil), do: ""

  defp module_line(module) do
    "[#{normalize_module_name(module)}]\n"
  end

  defp normalize_module_name(module) do
    inspect(module)
  end
end
