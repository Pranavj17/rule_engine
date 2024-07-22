defmodule RuleEngine.Parsers.Elasticsearch do
  @callback reconstruct(term) :: Map.t()

  def behaviour, do: RuleEngine.Behaviours.Elasticsearch

  def reconstruct(query), do: %{bool: query}

  def range(name, operator, values) when is_list(operator) do
    result =
      operator
      |> Enum.with_index()
      |> Enum.map(fn {operator, index} ->
        {operator, Enum.at(values, index)}
      end)
      |> Enum.reject(fn {_, value} -> is_nil(value) end)
      |> Enum.into(%{})

    %{
      range: %{
        "#{name}" => result
      }
    }
  end

  def range(name, operator, value) do
    %{range: %{"#{name}" => %{"#{operator}": value}}}
  end

  def exists(name) do
    %{exists: %{field: name}}
  end

  def terms(name, values) do
    %{terms: %{"#{name}": values}}
  end

  def term(name, values) do
    %{term: %{"#{name}": values}}
  end

  def filter(query) do
    %{filter: query}
  end

  def must(conditions) do
    {:must, conditions}
  end

  def should(conditions) do
    {:should, conditions}
  end

  def must_not(conditions) do
    {:must_not, conditions}
  end

  def no_match({type, conditions}) do
    {type, conditions}
  end
end
