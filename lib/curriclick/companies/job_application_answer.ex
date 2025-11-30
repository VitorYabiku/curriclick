defmodule Curriclick.Companies.JobApplicationAnswer do
  use Ash.Resource,
    otp_app: :curriclick,
    domain: Curriclick.Companies,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "job_application_answers"
    repo Curriclick.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:answer, :job_application_id, :requirement_id]
    end

    update :update do
      primary? true
      accept [:answer]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :answer, :string do
      allow_nil? false
      public? true
      constraints max_length: 10_000
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :job_application, Curriclick.Companies.JobApplication do
      allow_nil? false
    end

    belongs_to :requirement, Curriclick.Companies.JobListingRequirement do
      allow_nil? false
    end
  end
end
