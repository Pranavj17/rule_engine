defmodule RuleEngineTest do
  use ExUnit.Case
  doctest RuleEngine

  test "greets the world" do
    assert RuleEngine.hello() == :world
  end
end
