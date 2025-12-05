defmodule Curriclick.Companies.JobListingMatch do
  @moduledoc """
  Represents a match result for a job listing search.
  """
  use Ash.Resource,
    data_layer: :embedded,
    domain: Curriclick.Companies

  attributes do
    attribute :id, :uuid do
      public? true
    end

    attribute :title, :string do
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :company_name, :string do
      public? true
    end

    attribute :company_id, :uuid do
      public? true
    end

    attribute :location, :string do
      public? true
    end

    attribute :work_type, :atom do
      public? true
    end

    attribute :remote_allowed, :boolean do
      public? true
    end

    attribute :min_salary, :decimal do
      public? true
    end

    attribute :max_salary, :decimal do
      public? true
    end

    attribute :currency, :atom do
      public? true
    end

    attribute :pay_period, :atom do
      public? true
    end

    attribute :match_score, :float do
      public? true
    end
  end
end
