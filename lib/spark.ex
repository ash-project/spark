defmodule Spark do
  @moduledoc """
  Documentation for `Spark`.
  """

  @doc """
  Returns all modules that implement the specified behaviour for a given otp_app.

  Should only be called at runtime, not at compile time, as it will have
  inconsistent results at compile time.
  """
  def sparks(otp_app, spark) do
    otp_app
    |> :application.get_key(:modules)
    |> case do
      {:ok, mods} when is_list(mods) ->
        mods

      _ ->
        []
    end
    |> Enum.filter(&Spark.Dsl.is?(&1, spark))
  end

  @doc "Returns true if the module implements the specified behavior"
  def implements_behaviour?(module, behaviour) do
    :attributes
    |> module.module_info()
    |> Enum.any?(fn
      {:behaviour, ^behaviour} ->
        true

      # optimizations, probably extremely minor but this is in a tight loop in some places
      {:behaviour, [^behaviour | _]} ->
        true

      {:behaviour, [_, ^behaviour | _]} ->
        true

      {:behaviour, [_, _, ^behaviour | _]} ->
        true

      # never seen a module with three behaviours in real life, let alone four.
      {:behaviour, behaviours} when is_list(behaviours) ->
        module in behaviours

      _ ->
        false
    end)
  rescue
    _ ->
      false
  end

  @doc "Returns the extensions a given DSL uses"
  def extensions(module) do
    Spark.Dsl.Extension.get_persisted(module, :extensions, [])
  end

  @doc "Returns the configured otp_app of a given DSL instance"
  def otp_app(module) do
    Spark.Dsl.Extension.get_persisted(module, :otp_app)
  end
end
