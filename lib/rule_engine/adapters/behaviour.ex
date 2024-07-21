defmodule RuleEngine.Adapters.Behaviour do
  @callback predefined_rules() :: Map.t()
end
