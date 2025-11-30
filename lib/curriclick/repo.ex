defmodule Curriclick.Repo do
  @moduledoc """
  The AshPostgres repository for the Curriclick application.
  """
  use AshPostgres.Repo,
    otp_app: :curriclick

  @impl true
  @spec installed_extensions() :: [String.t()]
  def installed_extensions do
    # Add extensions here, and the migration generator will install them.
    ["ash-functions", "citext", "vector"]
  end

  # Don't open unnecessary transactions
  # will default to `false` in 4.0
  @impl true
  @spec prefer_transaction?() :: boolean()
  def prefer_transaction? do
    false
  end

  @impl true
  @spec min_pg_version() :: Version.t()
  def min_pg_version do
    %Version{major: 17, minor: 6, patch: 0}
  end
end
