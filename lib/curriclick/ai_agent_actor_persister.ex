defmodule Curriclick.AiAgentActorPersister do
  @moduledoc """
  Persists and retrieves the actor (User) for AshOban triggers in the context of AI agents.
  """
  use AshOban.ActorPersister

  @spec store(Curriclick.Accounts.User.t()) :: map()
  def store(%Curriclick.Accounts.User{id: id}), do: %{"type" => "user", "id" => id}

  @spec lookup(map() | nil) :: {:ok, Curriclick.Accounts.User.t() | nil} | {:error, any()}
  def lookup(%{"type" => "user", "id" => id}) do
    with {:ok, user} <- Ash.get(Curriclick.Accounts.User, id, authorize?: false) do
      # you can change the behavior of actions
      # or what your policies allow
      # using the `chat_agent?` metadata
      {:ok, Ash.Resource.set_metadata(user, %{chat_agent?: true})}
    end
  end

  # This allows you to set a default actor
  # in cases where no actor was present
  # when scheduling.
  @spec lookup(nil) :: {:ok, nil}
  def lookup(nil), do: {:ok, nil}
end
