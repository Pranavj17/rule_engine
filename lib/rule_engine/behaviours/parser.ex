defmodule RuleEngine.Behaviours.Parser do
  @callback predefined_rules() :: map()
  @callback whitelisted_attributes() :: map()
end
