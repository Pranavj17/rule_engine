defmodule RuleEngine.Parser do
  defmacro __using__(opts) do
    adapter = Keyword.get(opts, :adapter)

    quote do
      use unquote(adapter)
      @behaviour unquote(adapter)
      defoverridable unquote(adapter)
    end
  end
end
