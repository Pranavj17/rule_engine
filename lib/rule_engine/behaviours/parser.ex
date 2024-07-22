defmodule RuleEngine.Behaviours.Parser do
  @callback predefined_rules() :: Map.t()
  @callback whitelisted_attributes() :: Map.t()
end
