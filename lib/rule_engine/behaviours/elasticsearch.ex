defmodule RuleEngine.Behaviours.Elasticsearch do
  @callback query({term, term}) :: Tuple.t()

  def query({:and, conditions}), do: RuleEngine.Parsers.Elasticsearch.must(conditions)
  def query({:or, conditions}), do: RuleEngine.Parsers.Elasticsearch.should(conditions)
  def query({:not, conditions}), do: RuleEngine.Parsers.Elasticsearch.must_not(conditions)
  def query({type, conditions}), do: RuleEngine.Parsers.Elasticsearch.no_match({type, conditions})
end
