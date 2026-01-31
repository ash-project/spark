# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Spark.Test.Contact.Info do
  @moduledoc false

  def first_name(contact) do
    Spark.Dsl.Extension.get_opt(contact, [:personal_details], :first_name)
  end

  def last_name(contact) do
    Spark.Dsl.Extension.get_opt(contact, [:personal_details], :last_name)
  end

  def contacter(contact) do
    Spark.Dsl.Extension.get_opt(contact, [:contact], :contacter)
  end

  def module(contact) do
    Spark.Dsl.Extension.get_opt(contact, [:contact], :module)
  end

  def presets(contact) do
    Spark.Dsl.Extension.get_entities(contact, [:presets])
  end
end
