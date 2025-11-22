defmodule Curriclick.Chat.Conversation do
  use Ash.Resource,
    otp_app: :curriclick,
    domain: Curriclick.Chat,
    extensions: [AshOban],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  oban do
    triggers do
      trigger :name_conversation do
        action :generate_name
        read_action :read
        worker_read_action :read
        queue :conversations
        lock_for_update? false
        worker_module_name Curriclick.Chat.Message.Workers.NameConversation
        scheduler_module_name Curriclick.Chat.Message.Schedulers.NameConversation
        where expr(needs_title)
      end
    end
  end

  postgres do
    table "conversations"
    repo Curriclick.Repo
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
      pagination keyset?: true, required?: false
    end

    create :create do
      accept [:title]
      change relate_actor(:user)
    end

    read :my_conversations do
      pagination keyset?: true, required?: false
      prepare build(default_sort: [inserted_at: :desc])
      filter expr(user_id == ^actor(:id))
    end

    update :generate_name do
      accept []
      transaction? false
      require_atomic? false
      change Curriclick.Chat.Conversation.Changes.GenerateName
    end

    action :meaning_of_the_universe, :string do
      run fn input, _ ->
        {:ok, "4206669"}
      end
    end
  end

  pub_sub do
    module CurriclickWeb.Endpoint
    prefix "chat"

    publish_all :create, ["conversations", :user_id] do
      transform fn notification -> {:create, notification.data} end
    end

    publish_all :update, ["conversations", :user_id] do
      transform fn notification -> {:update, notification.data} end
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :title, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    has_many :messages, Curriclick.Chat.Message do
      public? true
    end

    belongs_to :user, Curriclick.Accounts.User do
      public? true
      allow_nil? false
    end
  end

  calculations do
    calculate :needs_title, :boolean do
      calculation expr(
                    is_nil(title) and
                      (count(messages) > 3 or
                         (count(messages) > 1 and inserted_at < ago(10, :minute)))
                  )
    end
  end
end
