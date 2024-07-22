defmodule RuleEngine.Behaviours.Elasticsearch do
  @callback reconstruct(term) :: Map.t()
end
