defmodule Curriclick.Companies.JobApplicationAnswer do
  @moduledoc """
  Represents a single answer to a job application requirement.
  """
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
      accept [:answer, :job_application_id, :requirement_id, :confidence_score, :confidence_explanation, :missing_info]
    end

    update :update do
      primary? true
      accept [:answer, :confidence_score, :confidence_explanation, :missing_info]
    end
  end

  code_interface do
    define :create
    define :update
  end

  attributes do
    uuid_primary_key :id

    attribute :answer, :string do
      allow_nil? true
      public? true
      constraints max_length: 10_000
    end

    attribute :confidence_score, :atom do
      constraints [one_of: [:low, :medium, :high]]
      public? true
      allow_nil? true
    end

    attribute :confidence_explanation, :string do
      public? true
    end

    attribute :missing_info, :string do
      public? true
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
