# defmodule Curriclick.Companies.JobListing.Calculations.MatchScore do
#   use Ash.Resource.Calculation
#
#   @impl true
#   def load(_query, _opts, _context) do
#     :description_vector
#   end
#
#   @impl true
#   def calculate(_records, _opts, %{arguments: %{search_text: search_text}}) do
#     dbg(search_text)
#     dbg(expr(description_vector))
#
#     case Curriclick.Ai.OpenAiEmbeddingModel.generate(
#            [search_text],
#            []
#          ) do
#       {:ok, [search_vector]} ->
#         Ash.Expr.expr(vector_cosine_distance(
#           description_vector,
#           ^search_vector
#         ))
#
#       {:error, error} ->
#         {:error, error}
#     end
#   end
# end

defmodule Curriclick.Companies.JobListing do
  use Ash.Resource,
    otp_app: :curriclick,
    domain: Curriclick.Companies,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource, AshAi]

  @find_matching_limit 20
  @minimum_similarity 0.55

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
        description "The user's ideal job description to match against for matching with job listings"
        allow_nil? false
        public? true
        constraints max_length: 2000
      end

      argument :limit, :integer do
        description "Maximum number of matching job listings to return"
        allow_nil? true
        public? true
        default @find_matching_limit
        constraints min: 1, max: 100
      end

      prepare before_action(fn query, _context ->
                limit = query.arguments.limit || 25
                search_text = query.arguments.ideal_job_description
                dbg(limit)
                dbg(search_text)

                query
                |> Ash.Query.limit(limit)

                # case Curriclick.Ai.OpenAiEmbeddingModel.generate(
                #        [search_text],
                #        []
                #      ) do
                #   {:ok, [search_vector]} ->
                #     dbg(search_vector)
                #     dbg(expr(vector_cosine_distance(description_vector, ^search_vector)))
                #
                #     query =
                #       query
                #       |> Ash.Query.limit(limit)
                #       #   # |> Ash.load(cosine_similarity: %{search_vector: search_vector})
                #       |> Ash.Query.load(:cosine_similarity)
                #       |> dbg()
                #
                #   {:error, error} ->
                #     {:error, error}
                # end

                # results =
                #   Curriclick.Companies.JobListing
                #   |> Ash.Query.build(load: [:id, :job_role_name, match_score: [search_text: search_text]], limit: limit)
                #   |> Ash.read!()
                #   |> dbg()
                #
                # :ok
              end)

      # prepare before_action(fn
      #           query, _context ->
      #             require Ash.Query
      #             dbg(query)
      #
      #             limit = query.arguments.limit || 25
      #             search_text = query.arguments.ideal_job_description
      #
      #             query
      #             |> Ash.Query.limit(limit)
      #             |> Ash.Query.load(match_score: [search_text: search_text])
      #             # |> Ash.Query.calculate(:match_score, :float, {} )
      #             |> dbg()
      #
      #           {:error, error} ->
      #             {:error, error}
      #         end)

      prepare after_action(fn query, results, _context ->
                dbg(results)
                #           dbg(query)
                #
                #           # results =
                #           #   Enum.map(results, fn jobListing ->
                #           #     Ash.Query.load(jobListing,
                #           #       match_score: [search_text: query.arguments.ideal_job_description]
                #           #     )
                #           #   end)
                #
                #           {:ok, results}
                #
                #           #           #           # Get the search vector from query context
                #           #           #           search_vector = query.context[:search_vector]
                #           #           #
                #           #           #           if search_vector do
                #           #           #             # Manually calculate and add match_score to each result
                #           #           #             # Use struct update to ensure the field is properly exposed
                #           #           # results_with_scores =
                #           #           #   Enum.map(results, fn job ->
                #           #           #     score = Curriclick.COmpa
                #           #           #
                #           #           #     # Add match_score as both a calculation result and in aggregates/calculations map
                #           #           #     job
                #           #           #     |> Map.put(:match_score, score)
                #           #           #   end)
                #           #           #       |> dbg()
                #           #           #
                #           #           #             {:ok, Enum.sort_by(results_with_scores, &(-&1.match_score))}
                #           #           #           else
                #           #           #             {:ok, results}
                #           #           #           end
                {:ok, results}
              end)
    end

    action :test_echo, :string do
      description "Echoes back the provided test_message on each returned job listing (in :test_echo_message)."

      argument :test_message, :string do
        allow_nil? false
        public? true
      end

      run fn input, _ctx ->
        dbg(input)
        echo_message = input.arguments.test_message
        dbg(echo_message)

        {:ok, "Echoing back from backend: #{echo_message}"}
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
    # Match scores are exposed through calculation loading in find_matching_jobs.
    calculate :cosine_similarity,
              :float,
              # expr(vector_cosine_distance(description_vector, ^arg(:search_vector))) do
              expr(5.69) do
      # argument :search_vector, {:array, :float} do
      #   allow_nil? false
      # end

      public? true
    end
  end
end
