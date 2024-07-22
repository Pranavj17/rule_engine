defmodule RuleEngine.Parser do
  defmacro __using__(opts) do
    parser = Keyword.get(opts, :parser)

    quote do
      @behaviour RuleEngine.Behaviours.Parser
      @module unquote(parser)

      @range_operator ["gt", "gte", "lt", "lte"]
      @terms_operator ["eq", "in"]
      @exists_operator "exists"

      def predefined_rules(), do: %{}
      def whitelisted_attributes(), do: %{}

      defp do_build({type, [rule | other_rules]}) do
        {type, [do_build_query(rule) | do_build(other_rules)]}
      end

      defp do_build({type, rule}) when is_map(rule) do
        {type, [do_build(rule)]}
      end

      defp do_build([rule | other_rules]) do
        [do_build_query(rule) | do_build(other_rules)]
      end

      defp do_build(rule) when is_map(rule) do
        do_build_query(rule)
      end

      defp do_build([]), do: []

      def build(rules) do
        Enum.map(rules, &do_build/1)
        |> query()
      end

      def query(conditions) do
        query =
          Enum.map(conditions, fn {type, conditions} ->
            conditions = Enum.reject(conditions, &is_nil/1)

            conditions =
              if(is_nested?(conditions), do: do_nested_query(conditions), else: conditions)

            do_query({type, conditions})
          end)
          |> Enum.into(%{})
          |> @module.reconstruct
      end

      defp do_query({:and, conditions}), do: @module.query({:must, conditions})
      defp do_query({:or, conditions}), do: @module.query({:or, conditions})
      defp do_query({:not, conditions}), do: @module.query({:not, conditions})
      defp do_query({:filter, conditions}), do: @module.query({:filter, conditions})

      defp do_nested_query(conditions) do
        nested_conditions = Enum.filter(conditions, &is_list/1)
        nested_query = Enum.map(nested_conditions, &query/1)
        Enum.filter(conditions, &is_map/1) ++ nested_query
      end

      defp is_nested?(conditions) do
        Enum.any?(conditions, &is_list/1)
      end

      defp do_build_query(%{
             name: name,
             operator: @exists_operator
           }) do
        @module.exists(name)
      end

      defp do_build_query(%{
             name: name,
             operator: operator,
             values: values
           })
           when operator in @terms_operator do
        if is_list(values) do
          @module.terms(name, values)
        else
          @module.term(name, values)
        end
      end

      defp do_build_query(%{
             name: name,
             type: "predefined"
           }) do
        rules = get_in(predefined_rules(), [name])

        if rules do
          Enum.map(rules, &do_build/1)
        else
          nil
        end
      end

      defp do_build_query(%{
             name: name,
             operator: operator,
             values: [value | _]
           })
           when is_binary(operator) and operator in @range_operator do
        @module.range(name, operator, value)
      end

      defp do_build_query(%{
             name: name,
             operator: operator,
             values: values
           })
           when is_list(operator) do
        @module.range(name, operator, values)
      end

      defp do_build_query(data), do: Enum.map(data, &do_build/1)
      defoverridable RuleEngine.Behaviours.Parser
    end
  end
end
