defmodule ModuleOMat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ModuleOMatWeb.Telemetry,
      ModuleOMat.Repo,
      {DNSCluster, query: Application.get_env(:module_o_mat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ModuleOMat.PubSub},
      ModuleOMat.Inventory.RemoteBackupScheduler,
      ModuleOMatWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ModuleOMat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ModuleOMatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
