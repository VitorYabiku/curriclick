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
    extensions: [AshTypescript.Resource, AshAi]

  require Ash.Query

  postgres do
    table "job_listings"
    repo Curriclick.Repo
  end

  typescript do
    type_name "JobListing"
  end

  vectorize do
    # Configure to vectorize individual attributes
    attributes description: :description_vector

    # Use after_action strategy to automatically generate embeddings
    strategy :after_action

    # Reference the custom embedding model
    embedding_model Curriclick.Ai.OpenAiEmbeddingModel
  end

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
      @result_count_limit 50

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

      prepare fn query, _context ->
        limit = query.arguments.limit || @result_count_limit
        search_text = query.arguments.ideal_job_description

        case Curriclick.Ai.OpenAiEmbeddingModel.generate([search_text], []) do
          {:ok, [search_vector]} ->
            query
            |> Ash.Query.sort(match_score: {%{search_vector: search_vector}, :desc_nils_last})
            |> Ash.Query.load(match_score: %{search_vector: search_vector})
            |> Ash.Query.limit(limit)

          {:error, error} ->
            Ash.Query.add_error(query, error)
        end
      end
    end

    create :create do
      accept [:job_role_name, :description, :company_id]
    end

    update :update do
      primary? true
      accept [:job_role_name, :description]
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

    attribute :job_role_name, :string do
      description "Name of the job role (e.g., Senior Machine Learning Engineer, Junior Developer, Product Manager)"
      allow_nil? false
      public? true
      constraints max_length: 255
    end

    attribute :description, :string do
      description "Description of the job listing, with everything you need to know about the position, the company, and the job requirements"
      allow_nil? false
      public? true
      constraints max_length: 3000
    end

    attribute :company_id, :uuid do
      description "ID of the company this job listing belongs to"
      allow_nil? false
      public? true
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
