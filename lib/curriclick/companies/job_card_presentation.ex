defmodule Curriclick.Companies.JobCardPresentation do
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

    attribute :match_quality, :atom do
      public? true
      allow_nil? false
      constraints one_of: [:bad_match, :moderate_match, :good_match, :very_good_match]
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

    attribute :success_probability, :float do
      public? true
      description "Probability (0-1) that the user would be successful in this role"
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

    attribute :remote_allowed, :boolean do
      public? true
    end

    attribute :work_type, :atom do
      public? true
    end

    attribute :salary_range, :string do
      public? true
      description "Formatted salary range string (e.g., '$80k-$120k USD/year')"
    end
  end
end
