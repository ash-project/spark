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
      ]
    ],
    entities: []
  }
  use Spark.Dsl.Extension, sections: [@my_section]
end
