defmodule Curriclick.Companies.JobApplication do
  use Ash.Resource,
    otp_app: :curriclick,
    domain: Curriclick.Companies,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "job_applications"
    repo Curriclick.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:user_id, :job_listing_id, :conversation_id, :search_query, :summary, :pros, :cons, :keywords, :match_quality, :hiring_probability, :missing_info]
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid do
      allow_nil? false
    end

    attribute :conversation_id, :uuid do
      allow_nil? true
    end

    attribute :job_listing_id, :uuid do
      allow_nil? false
    end

    attribute :search_query, :string do
      allow_nil? true
      public? true
    end

    attribute :summary, :string do
      allow_nil? true
      public? true
    end

    attribute :pros, {:array, :string} do
      public? true
      default []
    end

    attribute :cons, {:array, :string} do
      public? true
      default []
    end

    attribute :keywords, {:array, :map} do
      public? true
      default []
    end

    attribute :match_quality, :atom do
      public? true
      constraints one_of: [:bad_match, :moderate_match, :good_match, :very_good_match]
    end

    attribute :hiring_probability, :float do
      public? true
      allow_nil? true
    end

    attribute :missing_info, :string do
      public? true
      allow_nil? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Curriclick.Accounts.User do
      allow_nil? false
    end

    belongs_to :conversation, Curriclick.Chat.Conversation do
      allow_nil? true
    end

    belongs_to :job_listing, Curriclick.Companies.JobListing do
      allow_nil? false
    end
  end

  identities do
    identity :unique_application, [:user_id, :job_listing_id]
  end
end
