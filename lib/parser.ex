defmodule RuleEngine.Parser do
  defmacro __using__(opts) do
    adapter = Keyword.get(opts, :adapter)

    quote do
      @behaviour RuleEngine.Adapters.Behaviour
      defdelegate whitelisted_attributes, to: unquote(adapter)
      defdelegate predefined_rules, to: unquote(adapter)
      def whitelisted_fields, do: Map.keys(whitelisted_attributes())

      def build(rules, filter \\ %{}) do
        config = %{
          whitelisted_attributes: whitelisted_attributes(),
          predefined_rules: predefined_rules(),
          whitelisted_fields: whitelisted_fields()
        }

        unquote(adapter).build(rules, filter, config)
      end

      defoverridable RuleEngine.Adapters.Behaviour
    end
  end
end
