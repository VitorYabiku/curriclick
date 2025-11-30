defmodule Curriclick.Companies.JobApplication.Generator do
  @moduledoc """
  Generates draft application answers based on user profile and job requirements.
  """
  require Logger
  alias Curriclick.Accounts.User
  alias Curriclick.Companies.JobListing
  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOpenAI
  alias LangChain.Message

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

  def generate(%User{} = user, %JobListing{} = job_listing) do
    # Ensure user profile is loaded
    user =
      if Ash.Resource.loaded?(user, @profile_fields) do
        user
      else
        Ash.load!(user, @profile_fields)
      end

    profile_summary = summarize_profile(user)
    requirements = job_listing.requirements

    # If no requirements, nothing to generate
    if Enum.empty?(requirements) do
      {:ok, %{}}
    end

    # Prepare requirements list for prompt
    requirements_text =
      requirements
      |> Enum.map(fn req -> "- [ID: #{req.id}] #{req.question}" end)
      |> Enum.join("\n")

    prompt = """
    You are an AI assistant helping a candidate apply for a job.
    Your task is to generate answers for the following job application questions based strictly on the user's profile.

    Candidate Profile:
    #{profile_summary}

    Job Title: #{job_listing.title}
    Job Description Summary: #{String.slice(job_listing.description || "", 0, 500)}...

    Application Questions:
    #{requirements_text}

    Instructions:
    - For EACH question, provide:
      1. An answer (in Portuguese, first person).
      2. A confidence score (:low, :medium, :high).
      3. A brief explanation for the confidence score.
      4. Notes on any missing information from the profile that would improve the answer.

    - If the information is missing from the profile:
      - State "Informação não disponível no perfil" in the answer or give a generic placeholder.
      - Set confidence to :low.
      - Explicitly state what is missing in the 'missing_info' field.

    Output Format:
    Return a JSON object where keys are the Requirement IDs (from the input list) and values are objects with:
    {
      "answer": "...",
      "confidence_score": "low" | "medium" | "high",
      "confidence_explanation": "...",
      "missing_info": "Details on missing info or null/false if complete"
    }
    """

    try do
      llm = ChatOpenAI.new!(%{model: "gpt-5-mini", temperature: 0.0})

      {:ok, result} =
        LLMChain.new!(%{llm: llm})
        |> LLMChain.add_message(Message.new_system!("You are a helpful job application assistant. Output valid JSON only."))
        |> LLMChain.add_message(Message.new_user!(prompt))
        |> LLMChain.run()

      content = result.last_message.content |> LangChain.Message.ContentPart.content_to_string()

      json_content =
        content
        |> String.replace(~r/^```json\s*/, "")
        |> String.replace(~r/\s*```$/, "")
        |> String.trim()

      case Jason.decode(json_content) do
        {:ok, data} when is_map(data) ->
          # Normalize keys and values
          normalized_data =
            Map.new(data, fn {req_id, answer_data} ->
              {req_id,
               %{
                 answer: answer_data["answer"],
                 confidence_score: normalize_score(answer_data["confidence_score"]),
                 confidence_explanation: answer_data["confidence_explanation"],
                 missing_info: normalize_missing_info(answer_data["missing_info"])
               }}
            end)

          {:ok, normalized_data}

        {:error, _} ->
          Logger.error("Failed to parse JSON from LLM: #{content}")
          {:error, :json_parse_error}
      end
    rescue
      e ->
        Logger.error("Error generating application draft: #{inspect(e)}")
        {:error, :generation_failed}
    end
  end

  defp normalize_score("high"), do: :high
  defp normalize_score("medium"), do: :medium
  defp normalize_score("low"), do: :low
  defp normalize_score(_), do: :low

  defp normalize_missing_info(nil), do: nil
  defp normalize_missing_info(false), do: nil
  defp normalize_missing_info(""), do: nil
  defp normalize_missing_info(val) when is_binary(val), do: val
  defp normalize_missing_info(_), do: "Check profile for missing details"

  # Reuse profile summarization logic (or extract to a shared helper later)
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
