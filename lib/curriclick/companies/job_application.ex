defmodule Curriclick.Companies.JobApplication do
  @moduledoc """
  Represents a user's application to a job listing.
  """
  use Ash.Resource,
    otp_app: :curriclick,
    domain: Curriclick.Companies,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAi, AshStateMachine],
    notifiers: [Ash.Notifier.PubSub]

  pub_sub do
    module CurriclickWeb.Endpoint
    prefix "user_applications"

    publish :create, [:user_id]
    publish :update, [:user_id]
    publish :destroy, [:user_id]
  end

  state_machine do
    state_attribute :status
    initial_states [:draft]
    default_initial_state :draft

    transitions do
      transition :submit, from: :draft, to: :applied
    end
  end

  postgres do
    table "job_applications"
    repo Curriclick.Repo
  end

  actions do
    defaults [:read, :update]

    destroy :destroy do
      primary? true
      change cascade_destroy(:answers)
    end

    create :create do
      primary? true
      accept [
        :user_id,
        :job_listing_id,
        :conversation_id,
        :search_query,
        :summary,
        :pros,
        :cons,
        :keywords,
        :match_quality,
        :hiring_probability,
        :missing_info,
        :work_type_score,
        :location_score,
        :salary_score,
        :remote_score,
        :skills_score,
        :status
      ]
      
      argument :answers, {:array, :map} do
        allow_nil? true
      end

      manage_relationship :answers, :answers, type: :create
    end

    action :generate_draft, {:array, Curriclick.Companies.JobApplication.DraftAnswer} do
      argument :job_listing_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false
      argument :conversation_id, :uuid, allow_nil?: true

      run prompt(
            fn _, _ ->
              LangChain.ChatModels.ChatOpenAI.new!(%{model: "gpt-5-mini"})
            end,
            prompt: &Curriclick.Companies.JobApplication.Prompt.generate_messages/2,
            tools: false
          )
    end

    action :chat_with_assistant, :string do
      argument :messages, {:array, :map}, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false
      argument :id, :uuid, allow_nil?: true

      run fn input, context ->
        require Logger
        Logger.info("Initializing manual LLM chain for chat_with_assistant")

        app_id = input.arguments[:id]
        user_id = input.arguments.user_id
        
        topic = if app_id, do: "job_application_chat:#{app_id}", else: "job_application_queue_chat:#{user_id}"

        # Load user for actor
        user = Curriclick.Accounts.User |> Ash.get!(user_id, authorize?: false)

        messages = Curriclick.Companies.JobApplication.ChatPrompt.generate_messages(input, context)

        # Define tools
        tools = [:update_answer]

        # Setup Chain
        chain =
          LangChain.Chains.LLMChain.new!(%{
            llm:
              LangChain.ChatModels.ChatOpenAI.new!(%{
                model: "gpt-5.1",
                stream: true
              })
          })
          |> LangChain.Chains.LLMChain.add_messages(messages)
          |> AshAi.setup_ash_ai(
            otp_app: :curriclick,
            tools: tools,
            actor: user
          )
          |> LangChain.Chains.LLMChain.add_callback(%{
            on_llm_new_delta: fn _chain, deltas ->
              Logger.debug("Received deltas in callback")
              deltas = List.wrap(deltas)

              Phoenix.PubSub.broadcast(
                Curriclick.PubSub,
                topic,
                {:chat_delta, topic, deltas}
              )

              :ok
            end,
            on_tool_error: fn _chain, error, _tool_call ->
              Logger.error("Tool execution error: #{inspect(error)}")
              {:ok, "Error executing tool: #{inspect(error)}"}
            end,
            on_tool_result: fn _chain, tool_result, _tool_call ->
              # If we are editing a specific app, we might know its ID from the tool call? 
              # But for now, let's just broadcast a generic update or try to infer.
              # The tool `update_answer` likely updates an answer which belongs to an app.
              # We can just broadcast a general "queue_updated" or specific app update if we can.
              
              # For simplicity, let's broadcast to the user's queue topic that something changed
              # Or rely on the liveview to refresh based on standard Ash notifications if enabled.
              # The original code broadcasted :application_updated.
              
              # We'll try to broadcast to the generic topic as well for feedback?
              # Actually, the LiveView listens to "job_applications" (general pubsub) for Ash notifications.
              # So normal Ash notifications should handle the data refresh.
              
              {:ok, tool_result}
            end
          })

        case LangChain.Chains.LLMChain.run(chain, mode: :while_needs_response) do
          {:ok, _chain} ->
            {:ok, "Complete"}

          {:error, reason} ->
            Logger.error("LLM Chain failed: #{inspect(reason)}")
            {:error, inspect(reason)}
        end
      end
    end

    update :nilify_conversation do
      accept []
      change set_attribute(:conversation_id, nil)
    end
    update :submit do
      change transition_state(:applied)
    end

    action :add_to_queue, :struct do
      argument :params, :map, allow_nil?: false
      argument :conversation_id, :uuid, allow_nil?: true

      run fn input, _context ->
        # Pattern match to guarantee necessary keys are present
        %{user_id: _, job_listing_id: _} = input.arguments.params

        params = Map.put(input.arguments.params, :status, :draft)

        with {:ok, application} <- Curriclick.Companies.JobApplication.create(params) do
          Task.start(fn ->
            Curriclick.Companies.JobApplication.process_queue_item(application, input.arguments.conversation_id)
          end)

          {:ok, application}
        end
      end
    end
  end

  code_interface do
    define :create
    define :add_to_queue, args: [:params, :conversation_id]
    define :submit
    define :generate_draft, args: [:job_listing_id, :user_id, :conversation_id]
    define :chat_with_assistant, args: [:user_id, :messages]
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid do
      allow_nil? false
    end

    attribute :conversation_id, :uuid do
      allow_nil? true
    end

    attribute :job_listing_id, :uuid do
      allow_nil? false
    end

    attribute :search_query, :string do
      allow_nil? true
      public? true
    end

    attribute :summary, :string do
      allow_nil? true
      public? true
    end

    attribute :pros, {:array, :string} do
      public? true
      default []
    end

    attribute :cons, {:array, :string} do
      public? true
      default []
    end

    attribute :keywords, {:array, :map} do
      public? true
      default []
    end

    attribute :match_quality, Curriclick.Companies.LLMEvaluation do
      public? true
    end

    attribute :hiring_probability, Curriclick.Companies.LLMEvaluation do
      public? true
      allow_nil? true
    end

    attribute :missing_info, :string do
      public? true
      allow_nil? true
    end

    attribute :work_type_score, Curriclick.Companies.LLMEvaluation do
      public? true
    end

    attribute :location_score, Curriclick.Companies.LLMEvaluation do
      public? true
    end

    attribute :salary_score, Curriclick.Companies.LLMEvaluation do
      public? true
    end

    attribute :remote_score, Curriclick.Companies.LLMEvaluation do
      public? true
    end

    attribute :skills_score, Curriclick.Companies.LLMEvaluation do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Curriclick.Accounts.User do
      allow_nil? false
    end

    belongs_to :conversation, Curriclick.Chat.Conversation do
      allow_nil? true
    end

    belongs_to :job_listing, Curriclick.Companies.JobListing do
      allow_nil? false
    end

    has_many :answers, Curriclick.Companies.JobApplicationAnswer
  end

  identities do
    identity :unique_application, [:user_id, :job_listing_id]
  end

  @doc false
  def process_queue_item(application, conversation_id) do
    require Logger

    try do
      # Generate answers using LLM
      case Curriclick.Companies.JobApplication.generate_draft(
             application.job_listing_id,
             application.user_id,
             conversation_id
           ) do
        {:ok, draft_answers} ->
          # Persist answers
          Enum.each(draft_answers, fn draft ->
            Curriclick.Companies.JobApplicationAnswer.create!(%{
              job_application_id: application.id,
              requirement_id: draft.requirement_id,
              answer: draft.answer,
              confidence_score: draft.confidence_score,
              confidence_explanation: draft.confidence_explanation,
              missing_info: draft.missing_info
            })
          end)

          # Broadcast update
          Phoenix.PubSub.broadcast(
            Curriclick.PubSub,
            "job_applications",
            {:application_updated, application.id}
          )

        {:error, error} ->
          Logger.error("Failed to generate draft answers: #{inspect(error)}")
      end
    rescue
      e ->
        Logger.error("Error processing queue item: #{inspect(e)}")
    end
  end
end
