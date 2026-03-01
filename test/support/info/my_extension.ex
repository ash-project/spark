# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule MyExtension do
  @moduledoc false

  @my_section %Spark.Dsl.Section{
    name: :my_section,
    schema: [
      map_option: [
        type: :map,
        required: false,
        default: %{}
      ],
      callback: [
        type: {:function, args: [:map], returns: :string},
        required: false
      ],
      handler: [
        type: {:or, [:string, {:function, args: [:map], returns: :string}]},
        required: false
      ]
    ],
    entities: []
  }
  use Spark.Dsl.Extension, sections: [@my_section]

  defmodule Dsl do
    @moduledoc false
    use Spark.Dsl, default_extensions: [extensions: MyExtension]
  end
end
