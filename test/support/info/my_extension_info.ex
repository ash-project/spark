# SPDX-FileCopyrightText: 2022 spark contributors <https://github.com/ash-project/spark/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule MyExtension.Info do
  @moduledoc false
  use Spark.InfoGenerator, extension: MyExtension, sections: [:my_section]
end
