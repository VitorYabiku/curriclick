defmodule Curriclick.Companies.JobListingRequirement do
  use Ash.Resource,
    otp_app: :curriclick,
    domain: Curriclick.Companies,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "job_listing_requirements"
    repo Curriclick.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:question, :job_listing_id]
    end

    update :update do
      primary? true
      accept [:question]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :question, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :job_listing, Curriclick.Companies.JobListing do
      allow_nil? false
    end
  end

  identities do
    identity :unique_req, [:job_listing_id, :question]
  end
end
