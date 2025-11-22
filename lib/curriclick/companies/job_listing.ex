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

    read :find_matching_jobs do
      description "Find job listings that match the user's ideal job description using AI embeddings"
      
      argument :ideal_job_description, :string do
        description "The user's ideal job description to match against"
        allow_nil? false
        constraints max_length: 2000
      end
      
      argument :limit, :integer do
        description "Maximum number of matching jobs to return"
        allow_nil? true
        default 25
        constraints min: 1, max: 100
      end

      prepare before_action(fn query, _context ->
        require Ash.Query
        
        # Generate embedding for the search query
        case Curriclick.Ai.OpenAiEmbeddingModel.generate([query.arguments.ideal_job_description], []) do
          {:ok, [search_vector]} ->
            query
            # Filter by cosine distance threshold (< 0.8 means > 20% similarity)
            |> Ash.Query.filter(fragment("description_vector <=> ?::vector", ^search_vector) < 0.8)
            |> Ash.Query.limit(query.arguments.limit || 25)
            |> Ash.Query.load(:company)
            # Store search vector for match score calculation
            |> Ash.Query.set_context(%{search_vector: search_vector})
            |> Ash.Query.after_action(fn _query, job_listings ->
              search_vector = _query.context[:search_vector]
              
              if search_vector do
                # Calculate match scores for all jobs in a single query
                job_ids_str = job_listings |> Enum.map(&"'#{&1.id}'") |> Enum.join(",")
                
                batch_query = """
                  SELECT 
                    id::text as job_id,
                    (1 - (description_vector <=> $1::vector)) * 100 as match_score
                  FROM job_listings 
                  WHERE id IN (#{job_ids_str}) AND description_vector IS NOT NULL
                """
                
                case Curriclick.Repo.query(batch_query, [search_vector]) do
                  {:ok, %{rows: rows}} ->
                    # Create a map of job_id -> match_score
                    scores_map = 
                      rows
                      |> Enum.into(%{}, fn [job_id, score] -> 
                        {job_id, Float.round(score, 1)}
                      end)
                    
                    # Add match scores to job listings
                    job_listings_with_scores = 
                      job_listings
                      |> Enum.map(fn job_listing ->
                        score = Map.get(scores_map, job_listing.id, 0.0)
                        Map.put(job_listing, :match_score, score)
                      end)
                      # Sort by match score (highest first)
                      |> Enum.sort_by(fn job_listing -> job_listing.match_score end, :desc)
                      
                    {:ok, job_listings_with_scores}
                    
                  {:error, error} ->
                    IO.puts("Batch query error: #{inspect(error)}")
                    # Fallback: add 0 scores and return unsorted
                    job_listings_with_scores = 
                      job_listings
                      |> Enum.map(fn job_listing ->
                        Map.put(job_listing, :match_score, 0.0)
                      end)
                    {:ok, job_listings_with_scores}
                end
              else
                {:ok, job_listings}
              end
            end)

          {:error, error} ->
            {:error, error}
        end
      end)
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
