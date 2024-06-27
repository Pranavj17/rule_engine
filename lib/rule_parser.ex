defmodule RuleEngine.RuleParser do
  @callback whitelisted_attributes() :: Map.t()
  @callback predefined_rules() :: Map.t()
  @callback whitelisted_fields() :: Map.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour RuleEngine.RuleParser

      # Operators
      @exists "exists"
      @equal_to "eq"
      @greater_than "gt"
      @in_operator "in"
      @timestamp_before "timestamp_before"

      # Rule Keys
      @field_type "type"
      @name "name"
      @operator "operator"
      @inverse "inverse"
      @values "values"

      # FieldTypes
      @attribute "attribute"
      @predefined "predefined"

      def whitelisted_attributes, do: %{}

      def predefined_rules, do: %{}

      def whitelisted_fields, do: Map.keys(whitelisted_attributes())

      def timestamp_before_operator, do: @timestamp_before

      def build(rules, filter \\ %{})

      def build(%{"and" => and_rules, "or" => or_rules}, filter) do
        %{must: es_query(and_rules), minimum_should_match: 1, should: es_query(or_rules)}
        |> add_filter(filter)
      end

      def build(%{"and" => rules}, filter) do
        %{must: es_query(rules)}
        |> add_filter(filter)
      end

      def build(%{"or" => rules}, filter) do
        %{minimum_should_match: 1, should: es_query(rules)}
        |> add_filter(filter)
      end

      def build(%{} = query, filter) do
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

      defp es_query([]), do: []

      defp es_query([rule | other_rules]) do
        [es_query(rule) | es_query(other_rules)] |> List.flatten()
      end

      defp es_query(%{"and" => rules}) do
        query = es_query(rules)

        %{bool: %{must: query}}
      end

      defp es_query(%{"or" => rules}) do
        query = es_query(rules)

        %{bool: %{should: query}}
      end

      defp es_query(%{@name => name, @field_type => @predefined}) do
        rule = Map.get(predefined_rules(), name, nil)

        if rule do
          es_query(rule)
        else
          []
        end
      end

      defp es_query(
             %{
               @name => name,
               @field_type => @attribute,
               @operator => @timestamp_before,
               @values => [no_of_days],
               @inverse => inverse
             } = attributes
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

        conditions = [
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

      defp es_query(%{
             @field_type => @attribute,
             @values => _values,
             @operator => @in_operator,
             @inverse => inverse
           }) do
        conditions = [
          %{exists: %{field: "___improbable_field_name___"}}
        ]

        do_query(inverse, conditions)
      end

      defp es_query(%{
             @field_type => @attribute,
             @name => name,
             @operator => @exists,
             @inverse => inverse
           }) do
        if name in whitelisted_fields() do
          conditions = [
            %{exists: %{field: name}}
          ]

          do_query(inverse, conditions)
        else
          []
        end
      end

      defp es_query(%{
             @field_type => @attribute,
             @name => name,
             @operator => @equal_to,
             @values => [value],
             @inverse => inverse
           })
           when is_boolean(value) do
        if name in whitelisted_fields() do
          attribute_name = Map.get(whitelisted_attributes(), name, name)

          conditions = [
            %{term: %{attribute_name => value}}
          ]

          do_query(inverse, conditions)
        else
          []
        end
      end

      defp es_query(%{
             @field_type => @attribute,
             @name => name,
             @operator => @equal_to,
             @values => values,
             @inverse => inverse
           }) do
        if name in whitelisted_fields() do
          attribute_name = Map.get(whitelisted_attributes(), name, name)
          downcased_values = values |> downcase_values()

          conditions = [
            %{terms: %{attribute_name => downcased_values}}
          ]

          do_query(inverse, conditions)
        else
          []
        end
      end

      defp es_query(%{
             @field_type => @attribute,
             @name => name,
             @operator => @greater_than,
             @values => [value | _],
             @inverse => inverse
           }) do
        if name in whitelisted_fields() do
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

      defp days_before_unix(number_of_days) do
        Timex.today()
        |> Timex.shift(days: -number_of_days)
        |> Timex.to_unix()
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

      defoverridable RuleEngine.RuleParser
    end
  end
end
