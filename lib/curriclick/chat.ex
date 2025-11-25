defmodule Curriclick.Chat do
  use Ash.Domain, otp_app: :curriclick, extensions: [AshAi, AshPhoenix]

  tools do
    tool :my_conversations, Curriclick.Chat.Conversation, :my_conversations do
      description """
      List the conversations available to the current user.
      """
    end

    tool :message_history_for_conversation, Curriclick.Chat.Message, :for_conversation do
      description """
      Retrieve the message history for a given conversation.
      """
    end
  end

  resources do
    resource Curriclick.Chat.Conversation do
      define :create_conversation, action: :create
      define :get_conversation, action: :read, get_by: [:id]
      define :delete_conversation, action: :destroy
      define :my_conversations
    end

    resource Curriclick.Chat.Message do
      define :message_history,
        action: :for_conversation,
        args: [:conversation_id],
        default_options: [query: [sort: [inserted_at: :desc]]]

      define :create_message, action: :create
    end
  end
end
