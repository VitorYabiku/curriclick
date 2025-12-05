defmodule Curriclick.Chat.Message do
  @moduledoc """
  Represents a message in a conversation.
  """
  use Ash.Resource,
    otp_app: :curriclick,
    domain: Curriclick.Chat,
    extensions: [AshOban],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  oban do
    triggers do
      trigger :respond do
        actor_persister Curriclick.AiAgentActorPersister
        action :respond
        read_action :read
        worker_read_action :read
        queue :chat_responses
        lock_for_update? false
        scheduler_cron false
        worker_module_name Curriclick.Chat.Message.Workers.Respond
        scheduler_module_name Curriclick.Chat.Message.Schedulers.Respond
        where expr(needs_response)
      end
    end
  end

  postgres do
    table "messages"
    repo Curriclick.Repo
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
      pagination keyset?: true, required?: false
    end

    read :for_conversation do
      pagination keyset?: true, required?: false
      argument :conversation_id, :uuid, allow_nil?: false

      prepare build(default_sort: [inserted_at: :desc])
      filter expr(conversation_id == ^arg(:conversation_id))
    end

    create :create do
      accept [:text]

      validate match(:text, ~r/\S/) do
        message "Message cannot be empty"
      end

      argument :conversation_id, :uuid do
        public? false
      end

      change Curriclick.Chat.Message.Changes.CreateConversationIfNotProvided
      change run_oban_trigger(:respond)
    end

    update :respond do
      accept []
      require_atomic? false
      transaction? false
      change Curriclick.Chat.Message.Changes.Respond
    end

    create :upsert_response do
      upsert? true
      accept [:id, :response_to_id, :conversation_id]
      argument :complete, :boolean, default: false
      argument :text, :string, allow_nil?: false, constraints: [trim?: false, allow_empty?: true]
      argument :tool_calls, {:array, :map}
      argument :tool_results, {:array, :map}

      # if updating
      #   if complete, set the text to the provided text
      #   if streaming still, add the text to the provided text
      change atomic_update(
               :text,
               {:atomic,
                expr(
                  if ^arg(:complete) do
                    ^arg(:text)
                  else
                    text <> ^arg(:text)
                  end
                )}
             )

      change atomic_update(
               :tool_calls,
               {:atomic,
                expr(
                  if not is_nil(^arg(:tool_calls)) do
                    fragment(
                      "? || ?",
                      tool_calls,
                      type(
                        ^arg(:tool_calls),
                        {:array, :map}
                      )
                    )
                  else
                    tool_calls
                  end
                )}
             )

      change atomic_update(
               :tool_results,
               {:atomic,
                expr(
                  if not is_nil(^arg(:tool_results)) do
                    fragment(
                      "? || ?",
                      tool_results,
                      type(
                        ^arg(:tool_results),
                        {:array, :map}
                      )
                    )
                  else
                    tool_results
                  end
                )}
             )

      # if creating, set the text attribute to the provided text
      change set_attribute(:text, arg(:text))
      change set_attribute(:complete, arg(:complete))
      change set_attribute(:source, :agent)
      change set_attribute(:tool_results, arg(:tool_results))
      change set_attribute(:tool_calls, arg(:tool_calls))

      # on update, only set complete to its new value
      upsert_fields [:complete]
    end
  end

  pub_sub do
    module CurriclickWeb.Endpoint
    prefix "chat"

    publish :create, ["messages", :conversation_id] do
      transform fn %{data: message} ->
        %{
          text: message.text,
          id: message.id,
          source: message.source,
          tool_calls: message.tool_calls,
          tool_results: message.tool_results,
          complete: message.complete,
          inserted_at: message.inserted_at,
          updated_at: message.updated_at
        }
      end
    end

    publish :upsert_response, ["messages", :conversation_id] do
      transform fn %{data: message} ->
        %{
          text: message.text,
          id: message.id,
          source: message.source,
          tool_calls: message.tool_calls,
          tool_results: message.tool_results,
          complete: message.complete,
          inserted_at: message.inserted_at,
          updated_at: message.updated_at
        }
      end
    end
  end

  attributes do
    timestamps()
    uuid_v7_primary_key :id, writable?: true

    attribute :text, :string do
      constraints allow_empty?: true, trim?: false
      public? true
      allow_nil? false
    end

    attribute :tool_calls, {:array, :map}
    attribute :tool_results, {:array, :map}

    attribute :source, Curriclick.Chat.Message.Types.Source do
      allow_nil? false
      public? true
      default :user
    end

    attribute :complete, :boolean do
      allow_nil? false
      default true
    end
  end

  relationships do
    belongs_to :conversation, Curriclick.Chat.Conversation do
      public? true
      allow_nil? false
    end

    belongs_to :response_to, __MODULE__ do
      public? true
    end

    has_one :response, __MODULE__ do
      public? true
      destination_attribute :response_to_id
    end
  end

  calculations do
    calculate :needs_response, :boolean do
      calculation expr(source == :user and not exists(response))
    end
  end
end
