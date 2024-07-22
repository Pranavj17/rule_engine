defmodule RuleEngine.Builder do
  defmacro __using__(_opts) do
    quote do
      import RuleEngine.Builder

      import Kernel,
        except: [
          >: 2,
          <: 2,
          in: 2,
          !=: 2,
          not: 1,
          and: 2,
          ==: 2,
          >=: 2,
          <=: 2
        ]

      def exists?(name) do
        unit_rule(name, "exists")
      end

      def left == right do
        unit_rule(left, "eq", right)
      end

      def left != right do
        unit_rule(left, "eq", right, true)
      end

      def left > right do
        unit_rule(left, "gt", right)
      end

      def left < right do
        unit_rule(left, "lt", right, true)
      end

      def left in right do
        unit_rule(left, "in", right)
      end

      def left >= right do
        unit_rule(left, "lte", right)
      end

      def left <= right do
        unit_rule(left, "gte", right, true)
      end

      def contains(name, value) do
        %{
          name: name,
          operator: "contains",
          values: [value]
        }
      end

      def unit_rule(left, op, right \\ nil, inverse \\ false)

      def unit_rule(left, op, right, inverse) do
        %{
          name: left,
          operator: op,
          values: List.wrap(right)
        }
      end

      def left and right when is_list(left) do
        [right | left]
      end

      def left and right do
        [left, right]
      end

      def rule(condition \\ :and, block_or_list)

      def rule(condition, do: block) do
        rule(condition, block)
      end

      def rule(:and, rule) when is_list(rule), do: %{and: rule}
      def rule(:and, rule), do: %{and: [rule]}
      def rule(:or, rule) when is_list(rule), do: %{or: rule}
      def rule(:or, rule), do: %{or: [rule]}
      def rule(:not, rule) when is_list(rule), do: %{not: rule}
      def rule(:not, rule), do: %{not: [rule]}
      def rule(:filter, rule) when is_list(rule), do: %{filter: [rule]}
      def rule(:filter, rule), do: %{filter: [rule]}
    end
  end
end
