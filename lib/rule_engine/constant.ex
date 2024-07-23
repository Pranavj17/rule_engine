defmodule RuleEngine.Constant do
  @moduledoc false
  defmacro defconst(key, value) do
    quote bind_quoted: [key: key, value: value] do
      def unquote(key)(), do: unquote(value)
    end
  end
end
