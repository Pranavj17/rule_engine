defmodule RuleEngine.Behaviours.Elasticsearch do
  @callback query({atom(), map()}) :: tuple()
  @callback do_query({atom(), map()}) :: tuple()

  def do_query({:exists, map}), do: RuleEngine.Parsers.Elasticsearch.exists(map)
  def do_query({:terms, map}), do: RuleEngine.Parsers.Elasticsearch.terms(map)
  def do_query({:term, map}), do: RuleEngine.Parsers.Elasticsearch.term(map)
  def do_query({:range, map}), do: RuleEngine.Parsers.Elasticsearch.range(map)

  def query({:and, conditions}), do: RuleEngine.Parsers.Elasticsearch.must(conditions)
  def query({:or, conditions}), do: RuleEngine.Parsers.Elasticsearch.should(conditions)
  def query({:not, conditions}), do: RuleEngine.Parsers.Elasticsearch.must_not(conditions)
  def query({type, conditions}), do: RuleEngine.Parsers.Elasticsearch.no_match({type, conditions})
end
