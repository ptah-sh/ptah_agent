defmodule PtahAgentTest do
  use ExUnit.Case
  doctest PtahAgent

  test "greets the world" do
    assert PtahAgent.hello() == :world
  end
end
