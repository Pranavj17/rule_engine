defmodule RuleEngine.Parser do
  defmacro __using__(opts) do
    adapter = Keyword.get(opts, :adapter)

    quote do
      @behaviour RuleEngine.Adapters.Behaviour
      @module unquote(adapter)
      defdelegate whitelisted_attributes, to: unquote(adapter)
      defdelegate predefined_rules, to: unquote(adapter)
      def whitelisted_fields, do: Map.keys(whitelisted_attributes())

      def build(rules) do
        Enum.map(rules, &@module.build/1)
        |> @module.query()
        |> IO.inspect()
      end

      defoverridable RuleEngine.Adapters.Behaviour
    end
  end
end
