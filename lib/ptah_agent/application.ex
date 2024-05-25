defmodule PtahAgent.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: PtahAgent.Worker.start_link(arg)
      # {PtahAgent.Worker, arg}
      {DockerClient, Application.get_env(:ptah_agent, :docker)},
      {PtahClient, Application.get_env(:ptah_agent, :ptah)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PtahAgent.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
