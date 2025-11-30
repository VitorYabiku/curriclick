defmodule Curriclick.Companies.JobApplication do
  @moduledoc """
  Represents a user's application to a job listing.
  """
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
      accept [:user_id, :job_listing_id, :conversation_id, :search_query, :summary, :pros, :cons, :keywords, :match_quality, :hiring_probability, :missing_info, :work_type_score, :location_score, :salary_score, :remote_score, :skills_score]
      
      argument :answers, {:array, :map} do
        allow_nil? true
      end

      manage_relationship :answers, :answers, type: :create
    end

    action :generate_draft, :map do
      argument :job_listing_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false

      run fn input, _context ->
        job_listing_id = input.arguments.job_listing_id
        user_id = input.arguments.user_id

        user = Curriclick.Accounts.User |> Ash.get!(user_id, authorize?: false)
        job_listing = Curriclick.Companies.JobListing |> Ash.Query.load(:requirements) |> Ash.get!(job_listing_id, authorize?: false)

        if Enum.empty?(job_listing.requirements) do
          {:ok, %{}}
        else
          Curriclick.Companies.JobApplication.Generator.generate(user, job_listing)
        end
      end
    end

    update :nilify_conversation do
      accept []
      change set_attribute(:conversation_id, nil)
    end
  end

  code_interface do
    define :create
    define :generate_draft, args: [:job_listing_id, :user_id]
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

    attribute :match_quality, Curriclick.Companies.LLMEvaluation do
      public? true
    end

    attribute :hiring_probability, Curriclick.Companies.LLMEvaluation do
      public? true
      allow_nil? true
    end

    attribute :missing_info, :string do
      public? true
      allow_nil? true
    end

    attribute :work_type_score, Curriclick.Companies.LLMEvaluation do
      public? true
    end

    attribute :location_score, Curriclick.Companies.LLMEvaluation do
      public? true
    end

    attribute :salary_score, Curriclick.Companies.LLMEvaluation do
      public? true
    end

    attribute :remote_score, Curriclick.Companies.LLMEvaluation do
      public? true
    end

    attribute :skills_score, Curriclick.Companies.LLMEvaluation do
      public? true
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

    has_many :answers, Curriclick.Companies.JobApplicationAnswer
  end

  identities do
    identity :unique_application, [:user_id, :job_listing_id]
  end
end
