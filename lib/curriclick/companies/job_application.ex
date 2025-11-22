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
      accept [:user_id, :job_listing_id, :search_query, :match_score]
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

    attribute :job_listing_id, :uuid do
      allow_nil? false
    end

    attribute :search_query, :string do
      allow_nil? true
      public? true
    end

    attribute :match_score, :float do
      allow_nil? true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Curriclick.Accounts.User do
      allow_nil? false
    end

    belongs_to :job_listing, Curriclick.Companies.JobListing do
      allow_nil? false
    end
  end

  identities do
    identity :unique_application, [:user_id, :job_listing_id]
  end
end
