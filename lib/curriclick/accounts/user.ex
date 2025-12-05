defmodule Curriclick.Accounts.User do
  @moduledoc """
  Represents a user in the system, including their profile and authentication data.
  """
  use Ash.Resource,
    otp_app: :curriclick,
    domain: Curriclick.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication, AshAi]

  require Ash.Query

  @profile_fields [
    :profile_job_interests,
    :profile_education,
    :profile_skills,
    :profile_experience,
    :profile_remote_preference,
    :profile_custom_instructions,
    :profile_first_name,
    :profile_last_name,
    :profile_birth_date,
    :profile_location,
    :profile_cpf,
    :profile_phone
  ]

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end

      confirmation :confirm_new_user do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? false
        require_interaction? true
        confirmed_at_field :confirmed_at
        auto_confirm_actions [:sign_in_with_magic_link, :reset_password_with_token]
        sender Curriclick.Accounts.User.Senders.SendNewUserConfirmationEmail
      end
    end

    tokens do
      enabled? true
      token_resource Curriclick.Accounts.Token
      signing_secret Curriclick.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      password :password do
        identity_field :email
        hash_provider AshAuthentication.BcryptProvider

        resettable do
          sender Curriclick.Accounts.User.Senders.SendPasswordResetEmail
          # these configurations will be the default in a future release
          password_reset_action_name :reset_password_with_token
          request_password_reset_action_name :request_password_reset_token
        end
      end

      magic_link do
        identity_field :email
        registration_enabled? true
        require_interaction? true

        sender Curriclick.Accounts.User.Senders.SendMagicLinkEmail
      end

      api_key :api_key do
        api_key_relationship :valid_api_keys
        api_key_hash_attribute :api_key_hash
      end
    end
  end

  postgres do
    table "users"
    repo Curriclick.Repo
  end

  code_interface do
    define :update_profile
    define :get_by_email, args: [:email]
    define :chat_with_profile_assistant, args: [:user_id, :messages]
  end

  actions do
    defaults [:read]

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    update :change_password do
      # Use this action to allow users to change their password by providing
      # their current password and a new password.

      require_atomic? false
      accept []
      argument :current_password, :string, sensitive?: true, allow_nil?: false

      argument :password, :string,
        sensitive?: true,
        allow_nil?: false,
        constraints: [min_length: 8]

      argument :password_confirmation, :string, sensitive?: true, allow_nil?: false

      validate confirm(:password, :password_confirmation)

      validate {AshAuthentication.Strategy.Password.PasswordValidation,
                strategy_name: :password, password_argument: :current_password}

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
    end

    read :sign_in_with_password do
      description "Attempt to sign in using a email and password."
      get? true

      argument :email, :ci_string do
        description "The email to use for retrieving the user."
        allow_nil? false
      end

      argument :password, :string do
        description "The password to check for the matching user."
        allow_nil? false
        sensitive? true
      end

      # validates the provided email and password and generates a token
      prepare AshAuthentication.Strategy.Password.SignInPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :sign_in_with_token do
      # In the generated sign in components, we validate the
      # email and password directly in the LiveView
      # and generate a short-lived token that can be used to sign in over
      # a standard controller action, exchanging it for a standard token.
      # This action performs that exchange. If you do not use the generated
      # liveviews, you may remove this action, and set
      # `sign_in_tokens_enabled? false` in the password strategy.

      description "Attempt to sign in using a short-lived sign in token."
      get? true

      argument :token, :string do
        description "The short-lived sign in token."
        allow_nil? false
        sensitive? true
      end

      # validates the provided sign in token and generates a token
      prepare AshAuthentication.Strategy.Password.SignInWithTokenPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :register_with_password do
      description "Register a new user with a email and password."

      argument :email, :ci_string do
        allow_nil? false
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # Sets the email from the argument
      change set_attribute(:email, arg(:email))

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    action :request_password_reset_token do
      description "Send password reset instructions to a user if they exist."

      argument :email, :ci_string do
        allow_nil? false
      end

      # creates a reset token and invokes the relevant senders
      run {AshAuthentication.Strategy.Password.RequestPasswordReset, action: :get_by_email}
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get? true

      argument :email, :ci_string do
        allow_nil? false
      end

      filter expr(email == ^arg(:email))
    end

    update :reset_password_with_token do
      argument :reset_token, :string do
        allow_nil? false
        sensitive? true
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # validates the provided reset token
      validate AshAuthentication.Strategy.Password.ResetTokenValidation

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange
    end

    create :sign_in_with_magic_link do
      description "Sign in or register a user with magic link."

      argument :token, :string do
        description "The token from the magic link that was sent to the user"
        allow_nil? false
      end

      upsert? true
      upsert_identity :unique_email
      upsert_fields [:email]

      # Uses the information from the token to create or sign in the user
      change AshAuthentication.Strategy.MagicLink.SignInChange

      metadata :token, :string do
        allow_nil? false
      end
    end

    action :request_magic_link do
      argument :email, :ci_string do
        allow_nil? false
      end

      run AshAuthentication.Strategy.MagicLink.Request
    end

    read :sign_in_with_api_key do
      argument :api_key, :string, allow_nil?: false
      prepare AshAuthentication.Strategy.ApiKey.SignInPreparation
    end

    read :my_profile do
      description "Return the authenticated user's saved profile"
      get? true
      prepare build(load: @profile_fields ++ [:profile_full_name])
    end

    update :update_profile do
      description "Edit the authenticated user's saved profile fields"
      require_atomic? false
      accept @profile_fields

      change fn changeset, _context ->
        normalize_profile_fields(changeset)
      end
    end

    action :chat_with_profile_assistant, :string do
      argument :messages, {:array, :map}, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false

      run fn input, context ->
        require Logger

        Logger.info("Initializing manual LLM chain for chat_with_profile_assistant")

        user_id = input.arguments.user_id
        topic = "user_profile_chat:#{user_id}"

        # Load user for actor
        user =
          Curriclick.Accounts.User
          |> Ash.get!(user_id, authorize?: false)
          |> Ash.load!(:profile_full_name)

        system_msg = LangChain.Message.new_system!(profile_assistant_system_prompt(user))

        history_messages =
          input.arguments.messages
          |> Enum.map(fn
            %{"source" => "user", "text" => text} -> LangChain.Message.new_user!(text)
            %{"source" => "assistant", "text" => text} -> LangChain.Message.new_assistant!(text)
            %{"source" => :user, "text" => text} -> LangChain.Message.new_user!(text)
            %{"source" => :assistant, "text" => text} -> LangChain.Message.new_assistant!(text)
            _ -> nil
          end)
          |> Enum.reject(&is_nil/1)

        messages = [system_msg | history_messages]

        # Define tools
        tools = [:update_user_profile]

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
              Logger.info("Tool execution success: #{inspect(tool_result)}")
              # Broadcast that profile was updated so UI can refresh
              Phoenix.PubSub.broadcast(
                Curriclick.PubSub,
                topic,
                {:profile_updated, user_id}
              )
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
  end

  defp profile_assistant_system_prompt(user) do
    """
    <role>
    You are a friendly and helpful career assistant for Curriclick.
    Your primary goal is to interview the user to complete their profile.
    A complete profile allows Curriclick to generate high-quality job applications automatically.
    </role>

    <context>
    Current User Profile:
    #{summarize_profile_for_assistant(user)}
    </context>

    <instructions>
    1. Analyze the user's current profile. Identify missing or incomplete information (e.g. skills, experience, education, contact info).
    2. Ask the user focused questions to fill in these gaps. Do not ask for everything at once. Pick 1-2 most important missing fields.
    3. If the user provides profile information:
       - Use the `update_user_profile` tool to save it.
       - Confirm to the user that you have updated their profile.
    4. If the user asks about job applications, job search, or the queue:
       - Politely remind them that you are their Profile Assistant.
       - Suggest they visit the Job Application Queue or Chat page for application-specific tasks.
    5. Be professional, encouraging, and concise.
    6. Speak in the language of the user (likely Portuguese, based on context).
    </instructions>
    """
  end

  defp summarize_profile_for_assistant(user) do
    """
    Name: #{user.profile_full_name || "#{user.profile_first_name} #{user.profile_last_name}"}
    Email: #{user.email}
    Phone: #{user.profile_phone || "Not provided"}
    CPF: #{user.profile_cpf || "Not provided"}
    Location: #{user.profile_location || "Not provided"}
    Skills: #{user.profile_skills || "Not provided"}
    Experience: #{user.profile_experience || "Not provided"}
    Education: #{user.profile_education || "Not provided"}
    Job Interests: #{user.profile_job_interests || "Not provided"}
    Remote Preference: #{user.profile_remote_preference || "Not provided"}
    Custom Instructions/About: #{user.profile_custom_instructions || "Not provided"}
    """
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    # Allow reads of a user record when the actor is that user.
    # This is used both for normal reads and for the bulk-read
    # authorization that happens before bulk updates (e.g. tools).
    policy action_type(:read) do
      authorize_if expr(id == ^actor(:id))
    end

    # Allow updating the profile only when the actor is the user
    # being updated. This must align with the bulk-update
    # authorization path used by AshAi.Tools.execute/3.
    policy action(:update_profile) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action(:chat_with_profile_assistant) do
      authorize_if expr(^arg(:user_id) == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      sensitive? true
    end

    attribute :confirmed_at, :utc_datetime_usec

    attribute :profile_job_interests, :string do
      public? true
      allow_nil? true
    end

    attribute :profile_education, :string do
      public? true
      allow_nil? true
    end

    attribute :profile_skills, :string do
      public? true
      allow_nil? true
    end

    attribute :profile_experience, :string do
      public? true
      allow_nil? true
    end

    attribute :profile_remote_preference, :atom do
      public? true
      allow_nil? true
      constraints one_of: [:remote_only, :remote_friendly, :hybrid, :on_site, :no_preference]
    end

    attribute :profile_custom_instructions, :string do
      public? true
      allow_nil? true
    end

    attribute :profile_first_name, :string do
      public? true
      allow_nil? true
    end

    attribute :profile_last_name, :string do
      public? true
      allow_nil? true
    end

    attribute :profile_birth_date, :date do
      public? true
      allow_nil? true
      sensitive? true
    end

    attribute :profile_location, :string do
      public? true
      allow_nil? true
      sensitive? true
    end

    attribute :profile_cpf, :string do
      public? true
      allow_nil? true
      sensitive? true
    end

    attribute :profile_phone, :string do
      public? true
      allow_nil? true
      sensitive? true
    end
  end

  relationships do
    has_many :valid_api_keys, Curriclick.Accounts.ApiKey do
      filter expr(valid)
    end

    has_many :applications, Curriclick.Companies.JobApplication
  end

  calculations do
    calculate :profile_full_name, :string do
      public? true

      calculation fn records, _ctx ->
        Enum.map(records, fn record ->
          [record.profile_first_name, record.profile_last_name]
          |> Enum.reject(&nil_or_blank?/1)
          |> Enum.join(" ")
          |> case do
            "" -> nil
            full -> full
          end
        end)
      end
    end
  end

  identities do
    identity :unique_email, [:email]
  end

  @spec normalize_profile_fields(Ash.Changeset.t()) :: Ash.Changeset.t()
  defp normalize_profile_fields(changeset) do
    Enum.reduce(@profile_fields, changeset, fn field, cs ->
      case Ash.Changeset.fetch_change(cs, field) do
        {:ok, ""} -> Ash.Changeset.force_change_attribute(cs, field, nil)
        {:ok, _} -> cs
        :error -> cs
      end
    end)
  end

  @spec nil_or_blank?(any()) :: boolean()
  defp nil_or_blank?(value), do: is_nil(value) or value == ""
end
