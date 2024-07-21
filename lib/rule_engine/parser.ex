defmodule RuleEngine.Parser do
  defmacro __using__(opts) do
    adapter = Keyword.get(opts, :adapter)

    quote do
      @behaviour RuleEngine.Adapters.Behaviour
      @module unquote(adapter)

      alias RuleEngine.Agent, as: RE_Agent
      def predefined_rules(), do: %{}

      def build(rules) do
        if map_size(predefined_rules()) > 0 do
          RE_Agent.update_state(predefined_rules())
        end

        Enum.map(rules, &@module.build/1)
        |> @module.query()
      end

      defoverridable RuleEngine.Adapters.Behaviour
    end
  end
end
