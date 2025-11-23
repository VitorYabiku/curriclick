# defmodule Curriclick.Companies.JobListing.Calculations.TestCalculation do
#   use Ash.Resource.Calculation
#
#   # @impl true
#   # def load(_query, _opts, _context) do
#   #   :description_vector
#   # end
#
#   @impl true
#   def calculate(records, _opts, %{arguments: %{test_argument: test_argument}}) do
#     dbg(test_argument)
#
#     records
#     |> Enum.map(fn _record ->
#       # %{record | test_calculation: test_argument}
#
#       test_argument
#     end)
#
#     # |> dbg()
#   end
# end

defmodule Curriclick.Companies.JobListing do
  use Ash.Resource,
    otp_app: :curriclick,
    domain: Curriclick.Companies,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource]

  require Ash.Query

  postgres do
    table "job_listings"
    repo Curriclick.Repo
  end

  typescript do
    type_name "JobListing"
  end

  # vectorize do
  #   # Configure to vectorize individual attributes
  #   attributes description: :description_vector
  #
  #   # Use after_action strategy to automatically generate embeddings
  #   strategy :after_action
  #
  #   # Reference the custom embedding model
  #   embedding_model Curriclick.Ai.OpenAiEmbeddingModel
  # end

  actions do
    defaults [:destroy]

    read :read do
      description "Read job listings"
      primary? true

      # pagination do
      #   keyset? true
      #   default_limit 20
      #   max_page_size 25
      # end
    end

    read :find_matching_jobs do
      @result_count_limit 20

      description "Find job listings that match the user's ideal job description using AI embeddings"

      argument :ideal_job_description, :string do
        description "The user's ideal job description to match against for matching with job listings"
        allow_nil? false
        public? true
        constraints max_length: 2000
      end

      argument :limit, :integer do
        description "Maximum number of matching job listings to return"
        allow_nil? true
        public? true
        default @result_count_limit
        constraints min: 1, max: 100
      end

      manual fn query, _ecto_query, _context ->
        search_text = query.arguments[:ideal_job_description]
        limit = query.arguments[:limit] || 20

        api_url = System.get_env("ELASTIC_API_URL")
        api_key = System.get_env("ELASTIC_API_KEY")

        if is_nil(api_url) or is_nil(api_key) do
          {:error, "ELASTIC_API_URL or ELASTIC_API_KEY environment variables are not set"}
        else
          api_url = String.trim_trailing(api_url, "/")
          url = "#{api_url}/job-postings/_search"

          headers = [
            {"Content-Type", "application/json"},
            {"Authorization", "ApiKey #{api_key}"}
          ]

          body = %{
            "min_score" => 5.0,
            "size" => limit,
            "query" => %{
              "semantic" => %{
                "field" => "description_semantic",
                "query" => search_text
              }
            }
          }

          case Req.post(url, json: body, headers: headers) do
            {:ok, %{status: 200, body: %{"hits" => %{"hits" => hits}}}} ->
              listings =
                Enum.flat_map(hits, fn hit ->
                  source = hit["_source"]

                  with {:ok, id} <- Ash.Type.cast_input(Ash.Type.UUID, source["id"]),
                       {:ok, company_id} <- Ash.Type.cast_input(Ash.Type.UUID, source["company_id"]) do
                    [
                      struct(__MODULE__, %{
                        id: id,
                        title: source["title"],
                        description: source["description"],
                        company_id: company_id,
                        location: source["location"],
                        work_type: (source["work_type"] && String.to_existing_atom(source["work_type"])) || nil,
                        remote_allowed: source["remote_allowed"] == 1.0 or source["remote_allowed"] == true,
                        min_salary: source["min_salary"],
                        max_salary: source["max_salary"],
                        currency: source["currency"],
                        pay_period: (source["pay_period"] && String.to_existing_atom(source["pay_period"])) || nil
                      })
                    ]
                  else
                    _ -> []
                  end
                end)

              {:ok, listings}

            {:ok, response} ->
              {:error, "Elasticsearch request failed: #{inspect(response.body)}"}

            {:error, error} ->
              {:error, "Request error: #{inspect(error)}"}
          end
        end
      end
    end

    create :create do
      accept [
        :original_id, :title, :description, :company_id, :location, :remote_allowed, :work_type,
        :formatted_work_type, :min_salary, :max_salary, :med_salary, :pay_period, :currency,
        :views, :applies, :original_listed_time, :job_posting_url, :application_url,
        :application_type, :expiry, :closed_time, :formatted_experience_level, :skills_desc,
        :listed_time, :posting_domain, :sponsored, :compensation_type, :normalized_salary,
        :zip_code, :fips
      ]
    end

    update :update do
      primary? true
      accept [:title, :description]
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

    attribute :original_id, :string do
      description "Original Job ID from CSV"
      public? true
      allow_nil? true
    end

    attribute :title, :string do
      description "Title of the job"
      allow_nil? false
      public? true
      constraints max_length: 255
    end

    attribute :description, :string do
      description "Description of the job listing"
      allow_nil? false
      public? true
      constraints max_length: 10000
    end

    attribute :company_id, :uuid do
      description "ID of the company this job listing belongs to"
      allow_nil? false
      public? true
    end

    attribute :location, :string do
      description "Location of the job"
      public? true
    end

    attribute :remote_allowed, :boolean do
      description "Whether the job is remote allowed"
      public? true
      allow_nil? true
    end

    attribute :work_type, :string do
      description "Work type: FULL_TIME, PART_TIME, etc."
      public? true
      allow_nil? true
    end

    attribute :formatted_work_type, :string do
      description "Formatted work type"
      public? true
      allow_nil? true
    end

    attribute :min_salary, :decimal do
      public? true
      allow_nil? true
    end

    attribute :max_salary, :decimal do
      public? true
      allow_nil? true
    end

    attribute :med_salary, :decimal do
      public? true
      allow_nil? true
    end

    attribute :pay_period, :string do
      public? true
      allow_nil? true
    end

    attribute :currency, :string do
      public? true
      allow_nil? true
      default "USD"
    end
    
    attribute :views, :integer do
      public? true
      allow_nil? true
    end
    
    attribute :applies, :integer do
      public? true
      allow_nil? true
    end
    
    attribute :original_listed_time, :float do
       public? true
       allow_nil? true
    end

    attribute :listed_time, :float do
       public? true
       allow_nil? true
    end
    
    attribute :expiry, :float do
       public? true
       allow_nil? true
    end
    
    attribute :closed_time, :float do
       public? true
       allow_nil? true
    end

    attribute :job_posting_url, :string do
      public? true
      allow_nil? true
    end

    attribute :application_url, :string do
      public? true
      allow_nil? true
    end

    attribute :application_type, :string do
      public? true
      allow_nil? true
    end

    attribute :formatted_experience_level, :string do
      public? true
      allow_nil? true
    end

    attribute :skills_desc, :string do
      public? true
      allow_nil? true
      constraints max_length: 10000
    end
    
    attribute :posting_domain, :string do
      public? true
      allow_nil? true
    end
    
    attribute :sponsored, :integer do
      public? true
      allow_nil? true
    end
    
    attribute :compensation_type, :string do
      public? true
      allow_nil? true
    end
    
    attribute :normalized_salary, :decimal do
      public? true
      allow_nil? true
    end
    
    attribute :zip_code, :string do
      public? true
      allow_nil? true
    end
    
    attribute :fips, :string do
      public? true
      allow_nil? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :company, Curriclick.Companies.Company do
      source_attribute :company_id
      destination_attribute :id
      public? true
    end

    has_many :applications, Curriclick.Companies.JobApplication

    # has_many :job_requirements, Curriclick.Companies.JobRequirement do
    #   destination_attribute :job_listing_id
    #   public? true
    # end
  end

  calculations do
    calculate :match_score,
              :float,
              expr(1 - vector_cosine_distance(description_vector, ^arg(:search_vector))) do
      argument :search_vector, {:array, :float} do
        allow_nil? false
      end

      public? true
    end

    calculate :cosine_distance,
              :float,
              expr(vector_cosine_distance(^arg(:vector1), ^arg(:vector2))) do
      argument :vector1, {:array, :float} do
        allow_nil? false
      end

      argument :vector2, {:array, :float} do
        allow_nil? false
      end

      public? true
    end
  end
end
