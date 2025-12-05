defmodule Curriclick.Companies.JobApplication.Prompt do
  @moduledoc """
  Generates prompts for the job application draft generation.
  """
  alias LangChain.Message
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
    :profile_phone,
    :profile_full_name
  ]

  def generate_messages(input, _context) do
    job_listing_id = input.arguments.job_listing_id
    user_id = input.arguments.user_id
    conversation_id = input.arguments[:conversation_id]

    # Load User
    user = Curriclick.Accounts.User |> Ash.get!(user_id, authorize?: false)

    user =
      if Ash.Resource.loaded?(user, @profile_fields) do
        user
      else
        Ash.load!(user, @profile_fields)
      end

    # Load Job Listing
    job_listing =
      Ash.get!(Curriclick.Companies.JobListing, job_listing_id,
        load: [:requirements],
        authorize?: false
      )

    # Load Conversation History
    history =
      if conversation_id do
        Curriclick.Chat.message_history!(conversation_id, query: [sort: [inserted_at: :asc]])
      else
        []
      end

    profile_summary = summarize_profile(user)
    requirements = job_listing.requirements || []

    requirements_text =
      Enum.map_join(requirements, "\n", fn req -> "- [ID: #{req.id}] #{req.question}" end)

    system_prompt = """
    You are an AI assistant helping a candidate apply for a job.
    Your task is to generate answers for the following job application questions based strictly on the user's profile and previous conversation context.

    Candidate Profile:
    #{profile_summary}

    Job Title: #{job_listing.title}
    Job Description Summary: #{String.slice(job_listing.description || "", 0, 500)}...

    Application Questions:
    #{requirements_text}

    Instructions:
    - For EACH question, provide:
      1. An answer.
         - IMPORTANT: For objective questions asking for specific personal data (e.g., "E-mail", "CPF", "Telefone", "Nome completo", "LinkedIn", "Portfolio"), provide ONLY the data itself, without any introductory text or punctuation (e.g., just "name@example.com", NOT "Meu email é name@example.com.").
         - For subjective or open-ended questions (e.g., "Por que você quer esta vaga?", "Descreva sua experiência"), answer in Portuguese.
      2. A confidence score (:low, :medium, :high).
      3. A brief explanation for the confidence score.
      4. Notes on any missing information from the profile that would improve the answer.
      5. The 'requirement_id' MUST match the ID provided in the Application Questions list.

    - If the information is missing from the profile or conversation:
      - Return `null` (nil) for the answer field. DO NOT generate placeholder text like "Informação não disponível".
      - Set confidence to :low.
      - Explicitly state what is missing in the 'missing_info' field.

    - Use the conversation history to find relevant information that might not be in the structured profile.
    """

    messages = [Message.new_system!(system_prompt)]

    # Add history messages
    history_messages =
      history
      |> Enum.map(fn msg ->
        case msg.source do
          :user -> Message.new_user!(msg.text)
          :system -> Message.new_system!(msg.text)
          :assistant -> Message.new_assistant!(msg.text)
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Add a final user prompt to trigger generation
    final_prompt = Message.new_user!("Generate the application draft answers now.")

    messages ++ history_messages ++ [final_prompt]
  end

  defp summarize_profile(user) do
    """
    Name: #{user.profile_full_name || "#{user.profile_first_name} #{user.profile_last_name}"}
    Email: #{user.email}
    Phone: #{user.profile_phone || "Not provided"}
    CPF: #{user.profile_cpf || "Not provided"}
    Location: #{user.profile_location || "Not provided"}
    Skills: #{user.profile_skills || "Not provided"}
    Experience: #{user.profile_experience || "Not provided"}
    Education: #{user.profile_education || "Not provided"}
    About: #{user.profile_custom_instructions || "Not provided"}
    """
  end
end
