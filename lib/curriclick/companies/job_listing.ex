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

  @result_count_default_limit 20

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

      pagination do
        keyset? true
        default_limit @result_count_default_limit
        max_page_size 25
      end
    end

    action :set_chat_job_cards, :boolean do
      description """
      <action_purpose>
        Display job cards in the chat UI side panel for user review and selection.
        Call this after filtering results from find_suitable_job_postings_for_user.
      </action_purpose>

      <instructions>
        - After calling find_suitable_job_postings_for_user and filtering to best 3-10 matches, call this tool.
        - For each job, provide enriched data: pros, cons, success_probability, missing_info, summary.
        - Set `selected: true` for jobs with very high match scores where you're confident the user would be interested.
        - The summary should be suitable for application confirmation (why this job fits the user).
        - Pros/cons should be specific to the user's profile, not generic.
      </instructions>
      """

      argument :conversation_id, :uuid do
        description "The conversation ID to broadcast job cards to"
        allow_nil? false
        public? true
      end

      argument :job_cards, {:array, Curriclick.Companies.JobCardPresentation} do
        description "List of job cards with enriched data for display"
        allow_nil? false
        public? true
      end

      run fn input, _context ->
        conversation_id = input.arguments.conversation_id
        job_cards = input.arguments.job_cards

        # Persist job cards to conversation
        # We use authorize?: false because this is a system-level tool execution
        # and we want to ensure the update happens regardless of specific policy states
        # (though we could also pass the actor from input.context if needed)
        Curriclick.Chat.Conversation
        |> Ash.Query.filter(id == ^conversation_id)
        |> Ash.read_one!(authorize?: false)
        |> Ash.Changeset.for_update(:update_job_cards, %{job_cards: job_cards})
        |> Ash.update!(authorize?: false)

        # Spawn a task to simulate streaming of job cards
        Task.start(fn ->
          # First, clear the current list
          Phoenix.PubSub.broadcast(
            Curriclick.PubSub,
            "chat:job_cards:#{conversation_id}",
            {:job_cards_reset, %{conversation_id: conversation_id}}
          )

          # Small initial delay
          Process.sleep(300)

          # Broadcast each card one by one
          Enum.each(job_cards, fn card ->
            Phoenix.PubSub.broadcast(
              Curriclick.PubSub,
              "chat:job_cards:#{conversation_id}",
              {:job_card_added, %{job_card: card, conversation_id: conversation_id}}
            )
            # Delay between cards to create the streaming effect
            Process.sleep(500)
          end)
        end)

        {:ok, true}
      end
    end

    action :find_matching_jobs, {:array, Curriclick.Companies.JobListingMatch} do
      description """
      <action_purpose>
        Find job listings that match the user's query using AI embeddings and hybrid search.
        The search engine is Elasticsearch with semantic search capabilities.
      </action_purpose>

      <instructions>
        <instruction_group name="Input Processing">
          - **Language**: All search queries MUST be converted to **English**.
          - **Execution Strategy**:
            - **Run Immediately**: Execute the search with whatever information the user has provided, even if it is basic or incomplete.
            - **Do Not Ask First**: Do NOT ask for clarification before running the tool. Show results first.
            - **Clarify Later**: Only ask for more details or clarification *after* presenting the initial results, and only if it would significantly improve the outcome.
          - **Ambiguity**: If the request is ambiguous, make a reasonable best guess, run the search, and then explain your assumptions in the final response.
          - **Profile Context**: When available, include `profile_context` (saved interests, skills, experience, location, remote preference, custom instructions) and `profile_remote_preference` so the service can bias results without asking the user again.
        </instruction_group>

        <instruction_group name="Tool Arguments">
          - **Relevance**: Only include arguments that are strictly relevant to the user's request. **OMIT** arguments that are not used (do not send `nil` or empty lists).
          - **Limit**: Request 20-30 results (`limit: 20` or `limit: 30`) to allow for post-filtering.
          - **Filters**: Only use filter arguments if the user **EXPLICITLY** specifies them.
        </instruction_group>

        <instruction_group name="Post-Processing & Output">
          - **Critical Filtering**: Filter the 20-30 results down to the best 3-10 matches based on the user's constraints (especially negative constraints like "no Java").
          - **Presentation Format**:
            - Provide a **summary** of the best job postings.
            - Include **Pros & Cons**, **Success Probability**, and **Missing Info** for each.
        </instruction_group>
      </instructions>

      <examples>
        <example>
          <user_input>
            "Sou um desenvolvedor Elixir sênior. Odeio Java. USD."
          </user_input>
          <tool_call>
            find_matching_jobs(%{
              query: "Senior Elixir Developer",
              limit: 30,
              currencies: [:USD],
              semantic_title_boost: 2.0,
              semantic_skills_boost: 2.0
            })
          </tool_call>
          <response_summary>
            "Encontrei 3 vagas para você (filtrei vagas Java):
            1. **Senior Elixir Engineer**...
            ..."
          </response_summary>
        </example>
      </examples>
      """

      argument :query, :string do
        description "The text to search for."
        allow_nil? true
        public? true
        constraints max_length: 2000
      end

      argument :profile_context, :string do
        description "Serialized user profile (interests, skills, experience, location, custom instructions, remote preference) to enrich the search."
        allow_nil? true
        public? true
        constraints max_length: 4000
      end

      argument :limit, :integer do
        description "Maximum number of results to fetch."
        allow_nil? true
        public? true
        default @result_count_default_limit
        constraints min: 1, max: 100
      end

      argument :min_score, :float do
        description "Minimum semantic score."
        allow_nil? true
        public? true
        default 5.0
      end

      # Semantic Boosts
      argument :semantic_aggregate_boost, :float do
        description "Boost for description_semantic."
        allow_nil? true
        public? true
        default 1.0
      end

      argument :semantic_title_boost, :float do
        description "Boost for title_semantic."
        allow_nil? true
        public? true
        default 0.0
      end

      argument :semantic_description_boost, :float do
        description "Boost for description_individual_semantic."
        allow_nil? true
        public? true
        default 0.0
      end

      argument :semantic_skills_boost, :float do
        description "Boost for skills_desc_semantic."
        allow_nil? true
        public? true
        default 0.0
      end

      argument :semantic_query_profile_boost, :float do
        description "Boost for query_profile_semantic."
        allow_nil? true
        public? true
        default 1.0
      end

      # Text Boosts
      argument :text_title_boost, :float do
        description "Boost for title text."
        allow_nil? true
        public? true
        default 0.0
      end

      argument :text_description_boost, :float do
        description "Boost for description text."
        allow_nil? true
        public? true
        default 0.0
      end

      argument :text_skills_boost, :float do
        description "Boost for skills_desc text."
        allow_nil? true
        public? true
        default 0.0
      end

      argument :text_query_profile_boost, :float do
        description "Boost for query_profile text."
        allow_nil? true
        public? true
        default 1.0
      end

      argument :profile_remote_preference, :atom do
        description "User's saved remote preference (remote_only, remote_friendly, hybrid, on_site, no_preference)."
        allow_nil? true
        public? true
        constraints one_of: [:remote_only, :remote_friendly, :hybrid, :on_site, :no_preference]
      end

      # Filters
      argument :work_types, {:array, :atom} do
        description "Filter by work types"
        allow_nil? true
        public? true

        constraints items: [
                      one_of: [
                        :CONTRACT,
                        :FULL_TIME,
                        :INTERNSHIP,
                        :OTHER,
                        :PART_TIME,
                        :TEMPORARY,
                        :VOLUNTEER
                      ]
                    ]
      end

      argument :remote_allowed, :boolean do
        description "Filter by remote allowed"
        allow_nil? true
        public? true
      end

      run fn input, _context ->
        query = input.arguments

        present? = fn text -> is_binary(text) and String.trim(text) != "" end

        search_text =
          case query[:query] do
            text when is_binary(text) -> if present?.(text), do: String.trim(text), else: nil
            _ -> nil
          end

        profile_context =
          case query[:profile_context] do
            text when is_binary(text) -> if present?.(text), do: String.trim(text), else: nil
            _ -> nil
          end

        limit = query[:limit] || @result_count_default_limit
        min_score = query[:min_score] || 5.0

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

          # Helper to add semantic clauses
          add_semantic = fn clauses, field, boost, text ->
            if present?.(text) && boost && boost > 0.0 do
              clauses ++
                [
                  %{
                    "semantic" => %{
                      "field" => field,
                      "query" => text,
                      "boost" => boost
                    }
                  }
                ]
            else
              clauses
            end
          end

          # Helper to add text match clauses
          add_text = fn clauses, field, boost, text ->
            if present?.(text) && boost && boost > 0.0 do
              clauses ++
                [
                  %{
                    "match" => %{
                      field => %{
                        "query" => text,
                        "boost" => boost
                      }
                    }
                  }
                ]
            else
              clauses
            end
          end

          should_clauses =
            []
            |> add_semantic.("description_semantic", query[:semantic_aggregate_boost], search_text)
            |> add_semantic.("title_semantic", query[:semantic_title_boost], search_text)
            |> add_semantic.(
              "description_individual_semantic",
              query[:semantic_description_boost],
              search_text
            )
            |> add_semantic.("skills_desc_semantic", query[:semantic_skills_boost], search_text)
            |> add_semantic.(
              "query_profile_semantic",
              query[:semantic_query_profile_boost],
              profile_context
            )
            |> add_text.("title", query[:text_title_boost], search_text)
            |> add_text.("description", query[:text_description_boost], search_text)
            |> add_text.("skills_desc", query[:text_skills_boost], search_text)
            |> add_text.("query_profile", query[:text_query_profile_boost], profile_context)

          # Helper to add term filters
          add_term_filter = fn clauses, field, value ->
            if value != nil do
              clauses ++ [%{"term" => %{field => value}}]
            else
              clauses
            end
          end

          # Helper to add terms filters
          add_terms_filter = fn clauses, field, values ->
            if values && values != [] do
              clauses ++ [%{"terms" => %{field => values}}]
            else
              clauses
            end
          end

          remote_allowed_from_profile =
            case query[:profile_remote_preference] do
              :remote_only -> true
              :remote_friendly -> true
              :on_site -> false
              _ -> nil
            end

          remote_allowed_filter =
            case {query[:remote_allowed], remote_allowed_from_profile} do
              {nil, profile_value} -> profile_value
              {explicit, _} -> explicit
            end

          filter_clauses =
            []
            |> add_terms_filter.("work_type", query[:work_types])
            |> add_term_filter.("remote_allowed", remote_allowed_filter)

          body = %{
            "min_score" => min_score,
            "size" => limit,
            "query" => %{
              "bool" => %{
                "should" => should_clauses,
                "filter" => filter_clauses,
                "minimum_should_match" => if(length(should_clauses) > 0, do: 1, else: 0)
              }
            }
          }

          case Req.post(url, json: body, headers: headers) do
            {:ok, %{status: 200, body: %{"hits" => %{"hits" => hits}}}} ->
              listings =
                Enum.flat_map(hits, fn hit ->
                  source = hit["_source"]
                  score = hit["_score"]

                  with {:ok, id} <- Ash.Type.cast_input(Ash.Type.UUID, source["id"]) do
                    [
                      struct(Curriclick.Companies.JobListingMatch, %{
                        id: id,
                        match_score: score,
                        title: source["title"],
                        description: source["description"],
                        # company_name: source["company_name"] # Needs to be available in ES or fetched
                        # Placeholder until company fetch is solved
                        company_name: "Unknown Company"
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
        :original_id,
        :title,
        :description,
        :company_id,
        :location,
        :remote_allowed,
        :work_type,
        :formatted_work_type,
        :min_salary,
        :max_salary,
        :med_salary,
        :pay_period,
        :currency,
        :views,
        :applies,
        :original_listed_time,
        :job_posting_url,
        :application_url,
        :application_type,
        :expiry,
        :closed_time,
        :formatted_experience_level,
        :skills_desc,
        :listed_time,
        :posting_domain,
        :sponsored,
        :compensation_type,
        :normalized_salary,
        :zip_code,
        :fips
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
      constraints max_length: 10_000
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

    attribute :work_type, :atom do
      description "Work type: FULL_TIME, PART_TIME, etc."
      public? true
      allow_nil? true

      constraints one_of: [
                    :CONTRACT,
                    :FULL_TIME,
                    :INTERNSHIP,
                    :OTHER,
                    :PART_TIME,
                    :TEMPORARY,
                    :VOLUNTEER
                  ]
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

    attribute :pay_period, :atom do
      public? true
      allow_nil? true
      constraints one_of: [:BIWEEKLY, :HOURLY, :MONTHLY, :WEEKLY, :YEARLY]
    end

    attribute :currency, :atom do
      public? true
      allow_nil? true
      default :USD
      constraints one_of: [:AUD, :BBD, :CAD, :EUR, :GBP, :USD, :BRL]
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

    attribute :application_type, :atom do
      public? true
      allow_nil? true
      constraints one_of: [:ComplexOnsiteApply, :OffsiteApply, :SimpleOnsiteApply, :UnknownApply]
    end

    attribute :formatted_experience_level, :atom do
      public? true
      allow_nil? true

      constraints one_of: [
                    :Associate,
                    :Director,
                    :"Entry level",
                    :Executive,
                    :Internship,
                    :"Mid-Senior level"
                  ]
    end

    attribute :skills_desc, :string do
      public? true
      allow_nil? true
      constraints max_length: 10_000
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
  end
end
