# defmodule Curriclick.Companies.JobListing.Calculations.MatchScore do
#   use Ash.Resource.Calculation
#
#   @impl true
#   def load(_query, _opts, _context) do
#     :description_vector
#   end
#
#   @impl true
#   def calculate(records, _opts, %{arguments: %{ideal_job_description: search_text}}) do
#     dbg(search_text)
#
#     case Curriclick.Ai.OpenAiEmbeddingModel.generate(
#            [search_text],
#            []
#          ) do
#       {:ok, [search_vector]} ->
#         Enum.map(records, fn record ->
#           match_score =
#             record
#             |> Ash.calculate!(
#               :cosine_similarity,
#               args: %{vector1: record.description_vector, vector2: search_vector}
#             )
#             |> dbg()
#
#           match_score
#         end)
#
#       {:error, error} ->
#         {:error, error}
#     end
#   end
# end

defmodule Curriclick.Companies.JobListing.Calculations.TestCalculation do
  use Ash.Resource.Calculation

  # @impl true
  # def load(_query, _opts, _context) do
  #   :description_vector
  # end

  @impl true
  def calculate(records, _opts, %{arguments: %{test_argument: test_argument}}) do
    dbg(test_argument)

    records
    |> Enum.map(fn _record ->
      # %{record | test_calculation: test_argument}

      test_argument
    end)

    # |> dbg()
  end
end

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

      # # Add default limit to avoid overwhelming the frontend with all jobs
      # pagination do
      #   keyset? true
      #   default_limit 20
      #   max_page_size 25
      # end
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
                limit = query.arguments.limit || 20
                search_text = query.arguments.ideal_job_description
                dbg(limit)
                dbg(search_text)

                case Curriclick.Ai.OpenAiEmbeddingModel.generate(
                       [search_text],
                       []
                     ) do
                  {:ok, [search_vector]} ->
                    query
                    # |> Ash.Query.load(
                    #   :description_vector,
                    #   match_score: %{search_vector: search_vector},
                    #   dummy_test: %{test_argument: 6669},
                    #   test_calculation: %{test_argument: 69.420}
                    # )
                    |> Ash.Query.load([
                      # :description_vector,
                      dummy_test: %{test_argument: 6669.0},
                      test_calculation: %{test_argument: 69.420}
                    ])
                    |> Ash.Query.limit(limit)
                    |> dbg()

                  {:error, error} ->
                    {:error, error}
                end
              end)

      prepare after_action(fn query, results, _context ->
                dbg(results)

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
    calculate :match_score,
              :float,
              expr(vector_cosine_distance(description_vector, ^arg(:search_vector))) do
      argument :search_vector, {:array, :float} do
        allow_nil? false
      end

      public? true
    end

    calculate :dummy_test,
              :float,
              expr(1.0 + ^arg(:test_argument)) do
      # expr(69.420 + test_argument) do
      argument :test_argument, :float do
        allow_nil? false
      end

      public? true
    end

    calculate :test_calculation,
              :float,
              {Curriclick.Companies.JobListing.Calculations.TestCalculation, []} do
      argument :test_argument, :float do
        allow_nil? false
      end

      public? true
    end
  end
end
