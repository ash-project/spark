# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AddExtensionTest do
  use ExUnit.Case

  test "extensions can add other extensions" do
    defmodule Ext0 do
      @moduledoc false
      use Spark.Dsl.Extension,
        sections: [%Spark.Dsl.Section{name: :ext0, schema: [name: [type: :atom]]}]
    end

    defmodule Ext1 do
      @moduledoc false
      use Spark.Dsl.Extension,
        sections: [%Spark.Dsl.Section{name: :ext1, schema: [name: [type: :atom]]}],
        add_extensions: [Ext0]
    end

    defmodule Dsl do
      @moduledoc false
      use Spark.Dsl, default_extensions: [extensions: Ext1]
    end

    defmodule Example do
      @moduledoc false
      use Dsl

      ext0 do
        name(:ext0)
      end

      ext1 do
        name(:ext1)
      end
    end

    assert Dsl.default_extensions() == [Ext0, Ext1]
    assert Spark.Dsl.Extension.get_persisted(Example, :extensions) == [Ext1, Ext0]
    assert Spark.Dsl.Extension.get_opt(Example, [:ext1], :name) == :ext1
    assert Spark.Dsl.Extension.get_opt(Example, [:ext0], :name) == :ext0
  end
end
