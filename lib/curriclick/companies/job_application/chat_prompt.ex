defmodule Curriclick.Companies.JobApplication.ChatPrompt do
  @moduledoc """
  Generates prompts for the job application chat assistant.
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
    require Logger
    Logger.info("Generating messages for chat assistant")
    user_id = input.arguments.user_id
    messages = input.arguments.messages

    # Load User
    user = Curriclick.Accounts.User |> Ash.get!(user_id, authorize?: false)

    user =
      if Ash.Resource.loaded?(user, @profile_fields) do
        user
      else
        Ash.load!(user, @profile_fields)
      end

    # Load Job Application with Answers and Job Listing
    application_id = input.arguments[:id]

    {target_application, other_applications} =
      if application_id do
        app =
          Curriclick.Companies.JobApplication
          |> Ash.get!(application_id, load: [:job_listing, answers: [:requirement]])

        job_listing = Ash.load!(app.job_listing, [:company, :requirements])
        app = Map.put(app, :job_listing, job_listing)

        others =
          Curriclick.Companies.JobApplication
          |> Ash.Query.filter(user_id == ^user_id and status == :draft and id != ^application_id)
          |> Ash.Query.load([job_listing: [:company], answers: [:requirement]])
          |> Ash.read!()

        {app, others}
      else
        apps =
          Curriclick.Companies.JobApplication
          |> Ash.Query.filter(user_id == ^user_id and status == :draft)
          |> Ash.Query.load([job_listing: [:company], answers: [:requirement]])
          |> Ash.read!()

        {nil, apps}
      end

    profile_summary = summarize_profile(user)

    answers_context =
      if target_application do
        (target_application.answers || [])
        |> Enum.map_join("\n", fn a ->
          """
          ---
          ID: #{a.id}
          Question: #{a.requirement.question}
          Current Answer: #{a.answer}
          Confidence: #{a.confidence_score}
          Explanation: #{a.confidence_explanation}
          Missing Info: #{a.missing_info || "None"}
          """
        end)
      else
        "No specific application selected. Refer to the queue below."
      end

    other_apps_context =
      other_applications
      |> Enum.map_join("\n\n", fn app ->
        relevant_answers =
          (app.answers || [])
          # If we are in queue mode (target_application is nil), show ALL answers or at least significant ones
          |> Enum.filter(fn a ->
            if target_application do
               a.confidence_score == :low or not is_nil(a.missing_info) or is_nil(a.answer) or a.answer == ""
            else
               # Show all answers for all apps if in queue mode? Might be too long.
               # Let's stick to problematic ones + context
               true
            end
          end)

        answers_str =
          if relevant_answers != [] do
            relevant_answers
            |> Enum.map_join("\n", fn a ->
              """
              ID: #{a.id}
              Question: #{a.requirement.question}
              Current Answer: #{a.answer || "Pending"}
              Missing Info: #{a.missing_info || "None"}
              """
            end)
          else
            "All answers look good or pending generation."
          end

        """
        Job: #{app.job_listing.title} at #{app.job_listing.company.name}
        Application ID: #{app.id}
        Date: #{app.inserted_at}
        ---
        #{answers_str}
        """
      end)

    job_context_str =
      if target_application do
        """
        Job Title: #{target_application.job_listing.title}
        Application ID: #{target_application.id}
        Company: #{target_application.job_listing.company.name}
        Date: #{target_application.inserted_at}
        """
      else
        "Focus: Managing the Job Application Queue (Overview)"
      end

    system_prompt = """
    <role>
    You are an expert career assistant helping a user refine their job application queue for Curriclick.
    Your goal is to help the user provide the best possible answers to the application questions across ALL their pending applications.
    You have access to the user's queue of draft applications.
    </role>

    <context>
    #{job_context_str}

    User Profile Summary:
    #{profile_summary}
    </context>

    <current_focus_application>
    #{answers_context}
    </current_focus_application>

    <application_queue>
    #{other_apps_context}
    </application_queue>

    <instructions>
    1. Analyze the user's request. You are acting as a queue manager.
    2. If the user provides new information or asks to improve an answer:
       - Identify which application(s) the info applies to.
       - Use the `update_answer` tool to update the application record using the answer IDs provided in the context.
       - IMPORTANT: If the user provides information that was previously missing, check if it is complete. If fully provided, set `missing_info` to null. If only partially provided, update `missing_info` to describe what is still missing.
    3. If the user provides general profile information (e.g., "My phone number is...", "Add React to my skills"):
       - Use the `update_user_profile` tool to update their global profile.
       - Note: This will help generate better answers for future applications.
    4. If the user wants to perform actions on applications (submit, delete, select):
       - Identify the application IDs from the context (Application ID field).
       - Use `confirm_applications` to submit/apply (only if the user explicitly asks to submit/apply).
       - Use `delete_applications` to remove/discard (only if the user explicitly asks to delete).
       - Use `select_applications` if the user explicitly asks to select them or if you want to highlight them for the user (e.g. "Which applications are for Google?").
    5. Be proactive in pointing out low confidence answers or missing information across the queue.
    6. Always address the user directly (2nd person) in their language (Portuguese usually).
    7. When updating an answer, explain briefly what you changed and why.
    8. When referencing an application, ALWAYS use the Job Title, Company Name, and Date. NEVER use the ID in the response text (only in tool calls).
    </instructions>
    """

    msgs = [Message.new_system!(system_prompt)]

    # Add history messages
    history_messages =
      messages
      |> Enum.map(fn
        %{"source" => "user", "text" => text} -> Message.new_user!(text)
        %{"source" => "assistant", "text" => text} -> Message.new_assistant!(text)
        %{"source" => :user, "text" => text} -> Message.new_user!(text)
        %{"source" => :assistant, "text" => text} -> Message.new_assistant!(text)
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    msgs = msgs ++ history_messages
    Logger.info("Prompt generation complete. Messages count: #{length(msgs)}")
    msgs
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
