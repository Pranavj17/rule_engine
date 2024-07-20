defmodule RuleEngine.Adapters.ElasticsearchCopy do
  def whitelisted_attributes, do: %{}
  def predefined_rules, do: %{}
  def whitelisted_fields, do: Map.keys(whitelisted_attributes())

  def build(rules, filter \\ %{}, config \\ %{})

  def build(%{"and" => and_rules, "or" => or_rules}, filter, config) do
    %{
      must: es_query(and_rules, config),
      minimum_should_match: 1,
      should: es_query(or_rules, config)
    }
    |> add_filter(filter)
  end

  def build(%{"and" => rules}, filter, config) do
    %{must: es_query(rules, config)}
    |> add_filter(filter)
  end

  def build(%{"or" => rules}, filter, config) do
    %{minimum_should_match: 1, should: es_query(rules, config)}
    |> add_filter(filter)
  end

  def build(%{} = query, filter, _config) do
    query
    |> add_filter(filter)
  end

  defp add_filter(query, filter) when filter == %{}, do: %{bool: query}

  defp add_filter(query, %{filter: filter}) do
    %{bool: Map.put(query, :filter, filter)}
  end

  defp add_filter(query, filter) when is_map(filter) do
    case Map.to_list(filter) do
      [{_field, [_ | _]}] ->
        %{bool: Map.put(query, :filter, %{terms: filter})}

      _ ->
        %{bool: Map.put(query, :filter, %{term: filter})}
    end
  end

  defp add_filter(query, _filter), do: %{bool: query}

  defp es_query([], _), do: []

  defp es_query([rule | other_rules], config) do
    [es_query(rule, config) | es_query(other_rules, config)] |> List.flatten()
  end

  defp es_query(%{"and" => rules}, config) do
    query = es_query(rules, config)

    %{bool: %{must: query}}
  end

  defp es_query(%{"or" => rules}, config) do
    query = es_query(rules, config)

    %{bool: %{should: query}}
  end

  defp es_query(
         %{
           "name" => name,
           "type" => "predefined"
         },
         config
       ) do
    rule = Map.get(config.predefined_rules, name, nil)

    if rule do
      es_query(rule, config)
    else
      []
    end
  end

  defp es_query(
         %{
           "name" => name,
           "type" => "attribute",
           "operator" => "timestamp_before",
           "values" => [no_of_days],
           "inverse" => inverse
         } = attributes,
         _config
       ) do
    sign = %{true: -1, false: 1}

    start_datetime =
      Timex.shift(
        # To be used only in tests
        attributes["current_time"] || DateTime.utc_now(),
        days: sign[inverse] * no_of_days
      )
      |> Timex.beginning_of_day()

    start_unix_timestamp = start_datetime |> DateTime.to_unix()

    end_unix_timestamp =
      start_datetime
      |> Timex.shift(days: 1)
      |> DateTime.to_unix()

    [
      %{
        range: %{
          name => %{
            gte: start_unix_timestamp,
            lt: end_unix_timestamp
          }
        }
      }
    ]
  end

  defp es_query(
         %{
           "type" => "attribute",
           "values" => _values,
           "operator" => "in",
           "inverse" => inverse
         },
         _config
       ) do
    conditions = [
      %{exists: %{field: "___improbable_field_name___"}}
    ]

    do_query(inverse, conditions)
  end

  defp es_query(
         %{
           "type" => "attribute",
           "name" => name,
           "operator" => "exists",
           "inverse" => inverse
         },
         config
       ) do
    if name in config.whitelisted_fields do
      conditions = [
        %{exists: %{field: name}}
      ]

      do_query(inverse, conditions)
    else
      []
    end
  end

  defp es_query(
         %{
           "type" => "attribute",
           "name" => name,
           "operator" => "eq",
           "values" => [value],
           "inverse" => inverse
         },
         config
       )
       when is_boolean(value) do
    if name in config.whitelisted_fields do
      attribute_name = Map.get(config.whitelisted_attributes, name, name)

      conditions = [
        %{term: %{attribute_name => value}}
      ]

      do_query(inverse, conditions)
    else
      []
    end
  end

  defp es_query(
         %{
           "type" => "attribute",
           "name" => name,
           "operator" => "eq",
           "values" => values,
           "inverse" => inverse
         },
         config
       ) do
    if name in config.whitelisted_fields do
      attribute_name = Map.get(config.whitelisted_attributes, name, name)
      downcased_values = values |> downcase_values()

      conditions = [
        %{terms: %{attribute_name => downcased_values}}
      ]

      do_query(inverse, conditions)
    else
      []
    end
  end

  defp es_query(
         %{
           "type" => "attribute",
           "name" => name,
           "operator" => "gt",
           "values" => [value | _],
           "inverse" => inverse
         },
         config
       ) do
    if name in config.whitelisted_fields do
      conditions = [
        %{range: %{name => %{gt: value}}}
      ]

      do_query(inverse, conditions)
    else
      []
    end
  end

  defp do_query(false, conditions) do
    %{
      bool: %{
        must: %{
          bool: %{
            must: conditions
          }
        }
      }
    }
  end

  defp do_query(true, conditions) do
    %{
      bool: %{
        must_not: %{
          bool: %{
            must: conditions
          }
        }
      }
    }
  end

  defp downcase_values(values) when is_list(values) do
    values
    |> Enum.map(&downcase_value/1)
  end

  defp downcase_values(_) do
    []
  end

  def downcase_value(value) when is_binary(value), do: String.downcase(value)
  def downcase_value(value), do: value
end
