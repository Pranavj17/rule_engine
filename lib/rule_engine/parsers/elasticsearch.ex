defmodule RuleEngine.Parsers.Elasticsearch do
  @moduledoc """
  Module has set of function which return elastic search queries
  """
  @callback reconstruct(map()) :: map()

  def behaviour, do: RuleEngine.Behaviours.Elasticsearch

  def reconstruct(query), do: %{bool: query}

  def range(%{
        name: name,
        operator: operator,
        values: values
      })
      when is_list(operator) do
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

  def range(%{
        name: name,
        operator: operator,
        values: value
      }) do
    %{range: %{"#{name}" => %{"#{operator}": value}}}
  end

  def exists(%{name: name}) do
    %{exists: %{field: name}}
  end

  def terms(%{name: name, values: values}) do
    %{terms: %{"#{name}": values}}
  end

  def term(%{name: name, values: values}) do
    %{term: %{"#{name}": values}}
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
