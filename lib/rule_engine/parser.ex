defmodule RuleEngine.Parser do
  defmacro __using__(opts) do
    adapter = Keyword.get(opts, :adapter)

    quote do
      @behaviour RuleEngine.Adapters.Behaviour
      @module unquote(adapter)
      @callbacks [:predefined_rules, :whitelisted_attributes]

      alias RuleEngine.Agent, as: RE_Agent
      def predefined_rules(), do: %{}
      def whitelisted_attributes(), do: %{}

      def build(rules) do
        :ok = update_callbacks_state()

        Enum.map(rules, &@module.build/1)
        |> @module.query()
      end

      defp update_callbacks_state() do
        @callbacks
        |> Enum.reduce(%{}, fn func_name, acc ->
          value = apply(__MODULE__, func_name, [])
          Map.merge(acc, %{"#{func_name}": value})
        end)
        |> RE_Agent.update_state()

        :ok
      end

      defoverridable RuleEngine.Adapters.Behaviour
    end
  end
end
