defmodule Curriclick.Companies.JobCardPresentation do
  @moduledoc """
  Structure for presenting job card data in the chat UI.
  """
  use Ash.Resource,
    data_layer: :embedded,
    domain: Curriclick.Companies

  attributes do
    attribute :job_id, :uuid do
      public? true
      allow_nil? false
    end

    attribute :title, :string do
      public? true
      allow_nil? false
    end

    attribute :company_name, :string do
      public? true
      allow_nil? false
    end

    attribute :location, :string do
      public? true
    end

    attribute :match_quality, Curriclick.Companies.LLMEvaluation do
      public? true
      allow_nil? false
      description "Subjective match quality assessment by LLM"
    end

    attribute :description, :string do
      public? true
      description "Full job description for detail view"
    end

    attribute :pros, {:array, :string} do
      public? true
      default []
    end

    attribute :cons, {:array, :string} do
      public? true
      default []
    end

    attribute :hiring_probability, Curriclick.Companies.LLMEvaluation do
      public? true
      description "Estimated likelihood of getting hired: low, medium, or high"
    end

    attribute :missing_info, :string do
      public? true
      description "Information missing from user profile that would improve match quality"
    end

    attribute :summary, :string do
      public? true
      description "LLM-generated summary for application confirmation"
    end

    attribute :selected, :boolean do
      public? true
      default false
      description "Whether this job is selected for application (LLM sets true for very high matches)"
    end

    attribute :keywords, {:array, Curriclick.Companies.Keyword} do
      public? true
      description "Keywords extracted from the job listing with explanations"
    end

    attribute :remote_allowed, :boolean do
      public? true
    end

    attribute :work_type, :string do
      public? true
    end

    attribute :salary_range, :string do
      public? true
      description "Formatted salary range string (e.g., '$80k-$120k USD/year')"
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

    attribute :requirements, {:array, :map} do
      public? true
      description "List of requirements/questions for the job"
    end
  end
end
