defmodule RuleEngine.Behaviours.Parser do
  @moduledoc """
  Module has callbacks which are defined to be overriden
  """
  @callback predefined_rules() :: map()
  @callback whitelisted_attributes() :: map()
end
