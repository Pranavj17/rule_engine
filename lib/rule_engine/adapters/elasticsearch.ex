defmodule RuleEngine.Adapters.Elasticsearch do
  @range_operator ["gt", "gte", "lt", "lte"]
  @terms_operator ["eq", "in"]
  @exists_operator "exists"
  alias RuleEngine.Agent, as: RE_Agent

  def build({type, [rule | other_rules]}) do
    {type, [do_build(rule) | build(other_rules)]}
  end

  def build({type, rule}) when is_map(rule) do
    {type, [build(rule)]}
  end

  def build([rule | other_rules]) do
    [do_build(rule) | build(other_rules)]
  end

  def build(rule) when is_map(rule) do
    do_build(rule)
  end

  def build([]), do: []

  defp do_build(%{
         name: name,
         type: "predefined"
       }) do
    state = RE_Agent.get_state()
    rule = get_in(state, [:predefined_rules, name])

    if rule do
      Enum.map(rule, &build/1)
    else
      nil
    end
  end

  defp do_build(%{
         name: name,
         operator: @exists_operator
       }) do
    %{exists: %{field: name}}
  end

  defp do_build(%{
         name: name,
         operator: operator,
         values: values
       })
       when operator in @terms_operator do
    if is_list(values) do
      %{terms: %{"#{name}": values}}
    else
      %{term: %{"#{name}": values}}
    end
  end

  defp do_build(%{
         name: name,
         operator: operator,
         values: [value | _]
       })
       when is_binary(operator) and operator in @range_operator do
    %{range: %{"#{name}" => %{"#{operator}": value}}}
  end

  defp do_build(%{
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

  defp do_build(data), do: Enum.map(data, &build/1)

  def query(conditions) do
    query =
      Enum.map(conditions, fn {type, conditions} ->
        conditions = Enum.reject(conditions, &is_nil/1)
        conditions = if(is_nested?(conditions), do: do_nested_query(conditions), else: conditions)
        do_query({type, conditions})
      end)
      |> Enum.into(%{})

    %{bool: query}
  end

  defp do_query({:and, conditions}) do
    {:must, conditions}
  end

  defp do_query({:or, conditions}) do
    {:should, conditions}
  end

  defp do_query({:not, conditions}) do
    {:must_not, conditions}
  end

  defp do_query({:filter, conditions}) do
    {:filter, conditions}
  end

  defp do_query({type, conditions}) do
    {type, conditions}
  end

  defp do_nested_query(conditions) do
    nested_conditions = Enum.filter(conditions, &is_list/1)
    nested_query = Enum.map(nested_conditions, &query/1)
    Enum.filter(conditions, &is_map/1) ++ nested_query
  end

  defp is_nested?(conditions) do
    Enum.any?(conditions, &is_list/1)
  end
end
