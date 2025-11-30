defmodule Curriclick.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  @spec start(atom(), any()) :: {:ok, pid()} | {:ok, pid(), any()} | {:error, any()}
  def start(_type, _args) do
    children = [
      CurriclickWeb.Telemetry,
      Curriclick.Repo,
      {DNSCluster, query: Application.get_env(:curriclick, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:curriclick, :ash_domains),
         Application.fetch_env!(:curriclick, Oban)
       )},
      {Phoenix.PubSub, name: Curriclick.PubSub},
      # Start a worker by calling: Curriclick.Worker.start_link(arg)
      # {Curriclick.Worker, arg},
      # Start to serve requests, typically the last entry
      CurriclickWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :curriclick]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Curriclick.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  @spec config_change(keyword(), keyword(), keyword()) :: :ok
  def config_change(changed, _new, removed) do
    CurriclickWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
