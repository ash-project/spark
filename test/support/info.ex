defmodule Spark.Test.Contact.Info do
  @moduledoc false

  def first_name(contact) do
    Spark.Dsl.Extension.get_opt(contact, [:personal_details], :first_name)
  end

  def last_name(contact) do
    Spark.Dsl.Extension.get_opt(contact, [:personal_details], :last_name)
  end
end
