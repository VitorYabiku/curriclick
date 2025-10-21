defmodule Curriclick.Companies.JobListing do
  use Ash.Resource,
    otp_app: :curriclick,
    domain: Curriclick.Companies,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource, AshAi]
  
  # Helper function to calculate cosine similarity between two vectors
  # Returns a value between -1 and 1
  defp calculate_similarity(vec1, vec2) do
    # Convert both vectors to lists if they aren't already
    list1 = case vec1 do
      %Ash.Vector{} = vec -> Ash.Vector.to_list(vec)
      data when is_list(data) -> data
      _ -> []
    end
    
    list2 = case vec2 do
      %Ash.Vector{} = vec -> Ash.Vector.to_list(vec)
      data when is_list(data) -> data
      _ -> []
    end
    
    # Calculate cosine similarity
    if length(list1) > 0 and length(list2) > 0 and length(list1) == length(list2) do
      # Calculate dot product
      dot_product = Enum.zip(list1, list2)
      |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)
      
      # Calculate magnitudes
      magnitude1 = :math.sqrt(Enum.reduce(list1, 0.0, fn x, acc -> acc + x * x end))
      magnitude2 = :math.sqrt(Enum.reduce(list2, 0.0, fn x, acc -> acc + x * x end))
      
      # Return cosine similarity
      if magnitude1 > 0 and magnitude2 > 0 do
        dot_product / (magnitude1 * magnitude2)
      else
        0.0
      end
    else
      0.0
    end
  end

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
