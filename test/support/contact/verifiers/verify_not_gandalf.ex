defmodule Spark.Test.Contact.Verifiers.VerifyNotGandalf do
  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier

  def verify(dsl) do
    if Spark.Test.Contact.Info.first_name(dsl) == "Gandalf" do
      {:error,
       Spark.Error.DslError.exception(
         message: "Cannot be gandalf",
         path: [:personal_details, :first_name],
         module: Verifier.get_persisted(dsl, :module)
       )}
    else
      :ok
    end
  end
end
