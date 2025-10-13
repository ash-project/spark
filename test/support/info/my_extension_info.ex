# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule MyExtension.Info do
  @moduledoc false
  use Spark.InfoGenerator, extension: MyExtension, sections: [:my_section]
end
