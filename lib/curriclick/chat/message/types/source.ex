defmodule Curriclick.Chat.Message.Types.Source do
  @moduledoc """
  The source of a message (:user or :agent).
  """
  use Ash.Type.Enum, values: [:agent, :user]
end
