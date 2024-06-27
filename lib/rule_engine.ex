defmodule RuleEngine do
  def parser do
    quote do
      use Core.RuleEngine.RuleParser
    end
  end

  def builder do
    quote do
      use Core.RuleEngine.RuleBuilder
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
