defmodule RuleEngine.Application do
  use Application

  def start(_type, _args) do
    children = [
      RuleEngine.Agent
    ]

    opts = [strategy: :one_for_one, name: RuleEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
