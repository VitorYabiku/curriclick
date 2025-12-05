defmodule Curriclick.Companies.Company do
  @moduledoc """
  Represents a company that posts job listings.
  """
  use Ash.Resource,
    otp_app: :curriclick,
    domain: Curriclick.Companies,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource]

  postgres do
    table "companies"
    repo Curriclick.Repo
  end

  typescript do
    type_name "Company"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description]
    end

    update :update do
      accept [:name, :description]
    end
  end

  policies do
    # For now, allow all operations - you can restrict this later based on your needs
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      description "Name of the company"
      allow_nil? false
      public? true
      constraints max_length: 255
    end

    #
    # attribute :industry, :string do
    #   description "Company's industry (e.g., Education, Technology, Mining, Oil and Gas)"
    #   allow_nil? false
    #   public? true
    #   constraints max_length: 100
    # end
    #
    # attribute :cnpj, :string do
    #   description "Brazilian company registration number (CNPJ)"
    #   allow_nil? false
    #   public? true
    #
    #   constraints match: ~r/^\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2}$|^\d{14}$/,
    #               max_length: 18
    # end

    attribute :description, :string do
      description "Detailed description of the company"
      allow_nil? true
      public? true
      constraints max_length: 2000
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :job_listings, Curriclick.Companies.JobListing do
      destination_attribute :company_id
    end
  end

  identities do
    identity :unique_name, [:name] do
      message "Uma empresa com esse mesmo nome já existe. Forneça um nome diferente."
    end
  end
end
