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
      
      # Add default limit to avoid overwhelming the frontend with all jobs
      pagination do
        offset? true
        default_limit 50
        max_page_size 100
      end
    end

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

    prepare before_action(fn query, _context ->
      # Generate embedding for the search query
      case Curriclick.Ai.OpenAiEmbeddingModel.generate([query.arguments.ideal_job_description], []) do
        {:ok, [search_vector]} ->
          require Ash.Query
          import Ash.Expr
          
          # Store the search vector in the query context so we can use it in after_action
          query
          |> Ash.Query.filter(expr(vector_cosine_distance(description_vector, ^search_vector) < 0.5))
          |> Ash.Query.limit(query.arguments.limit || 25)
          |> Ash.Query.load(:company)
          |> Ash.Query.ensure_selected([:description_vector])
          |> Ash.Query.set_context(%{search_vector: search_vector})

        {:error, error} ->
          Ash.Query.add_error(query, error)
      end
    end)
    
    prepare after_action(fn query, results, _context ->
      # Get the search vector from query context
      search_vector = query.context[:search_vector]
      
      if search_vector do
        # Manually calculate and add match_score to each result
        results_with_scores = Enum.map(results, fn job ->
          score = calculate_similarity(job.description_vector, search_vector)
          Map.put(job, :match_score, score)
        end)
        {:ok, Enum.sort_by(results_with_scores, & -&1.match_score)}
      else
        {:ok, results}
      end
    end)
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

  calculations do
    calculate :match_score, :float do
      description """
      Similarity score between -1 and 1 representing match quality:
      - 1.0: Perfect match (identical embeddings)
      - 0.0: No correlation (orthogonal vectors)
      - -1.0: Opposite match (completely dissimilar)
      
      This is the cosine similarity of the job description embedding
      with the search query embedding.
      """
      
      argument :search_vector, {:array, :float} do
        allow_nil? false
      end
      
      calculation expr(
        # Convert cosine distance to cosine similarity
        # Cosine similarity = 1 - cosine distance
        # This gives us values from -1 (opposite) to 1 (identical)
        1 - vector_cosine_distance(description_vector, ^arg(:search_vector))
      )
    end
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
end
