defmodule RuleEngine.Adapters.Behaviour do
  @callback whitelisted_attributes() :: Map.t()
  @callback predefined_rules() :: Map.t()
  @callback whitelisted_fields() :: Map.t()
end
