defmodule RuleEngine.Parser do
  @moduledoc """
  Module to parser the rule given and translater the rules respective to the parser specified
  """
  defmacro __using__(opts) do
    parser = Keyword.get(opts, :parser)

    quote do
      @behaviour RuleEngine.Behaviours.Parser
      @module unquote(parser)
      @parser_behaviour @module.behaviour()
      @behaviour @parser_behaviour

      @range_operator ["gt", "gte", "lt", "lte"]
      @terms_operator ["eq", "in"]
      @exists_operator "exists"

      def predefined_rules(), do: %{}
      def whitelisted_attributes(), do: %{}

      defdelegate do_query(conditions), to: @parser_behaviour, as: :query

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
        Enum.map(conditions, fn {type, conditions} ->
          conditions = Enum.reject(conditions, &is_nil/1)

          conditions =
            if(nested?(conditions), do: do_nested_query(conditions), else: conditions)

          do_query({type, conditions})
        end)
        |> Enum.into(%{})
        |> @module.reconstruct
      end

      defp do_nested_query(conditions) do
        nested_conditions = Enum.filter(conditions, &is_list/1)
        nested_query = Enum.map(nested_conditions, &query/1)
        Enum.filter(conditions, &is_map/1) ++ nested_query
      end

      defp nested?(conditions) do
        Enum.any?(conditions, &is_list/1)
      end

      defp do_build_query(%{
             name: name,
             operator: @exists_operator
           }) do
        @parser_behaviour.do_query({:exists, %{name: name}})
      end

      defp do_build_query(%{
             name: name,
             operator: operator,
             values: values
           })
           when operator in @terms_operator do
        map = %{name: name, values: values}

        if is_list(values) do
          @parser_behaviour.do_query({:terms, map})
        else
          @parser_behaviour.do_query({:term, map})
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
        map = %{
          name: name,
          operator: operator,
          values: value
        }

        @parser_behaviour.do_query({:range, map})
      end

      defp do_build_query(%{
             name: name,
             operator: operator,
             values: values
           })
           when is_list(operator) do
        map = %{
          name: name,
          operator: operator,
          values: values
        }

        @parser_behaviour.do_query({:range, map})
      end

      defp do_build_query(data), do: Enum.map(data, &do_build/1)
      defoverridable RuleEngine.Behaviours.Parser
    end
  end
end
