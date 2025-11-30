defmodule Curriclick.Secrets do
  @moduledoc """
  Provides access to application secrets for AshAuthentication.
  """
  use AshAuthentication.Secret

  @spec secret_for([atom()], Ash.Resource.t(), keyword(), map()) :: {:ok, String.t()} | :error
  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Curriclick.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:curriclick, :token_signing_secret)
  end
end
