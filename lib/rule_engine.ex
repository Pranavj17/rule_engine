defmodule RuleEngine do
  def parser do
    quote do
      use RuleEngine.Parser,
        adapter: RuleEngine.Adapters.Elasticsearch
    end
  end

  def builder do
    quote do
      use RuleEngine.Builder
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
