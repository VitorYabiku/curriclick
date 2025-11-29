defmodule Curriclick.Chat.Message.Changes.Respond do
  use Ash.Resource.Change
  require Ash.Query

  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOpenAI
  # alias LangChain.ChatModels.ChatGoogleAI
  require Logger
  alias Curriclick.Accounts.User

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      message = changeset.data
      actor = context.actor

      profile_summary = summarize_profile(actor)

      messages =
        Curriclick.Chat.Message
        |> Ash.Query.filter(conversation_id == ^message.conversation_id)
        |> Ash.Query.filter(id != ^message.id)
        |> Ash.Query.select([:text, :source, :tool_calls, :tool_results])
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.read!()
        |> Enum.concat([%{source: :user, text: message.text}])

      system_prompt =
        LangChain.Message.new_system!("""
        <role>
        You are a career assistant for Curriclick, an AI-powered job search platform focused on helping people in Brazil find jobs.
        Your mission is to help each user discover and evaluate job opportunities that match their skills, experience, goals, and practical constraints.
        </role>

        <language_behavior>
        - Always reply to the user in the SAME language they use in their messages.
        - If the user's language is ambiguous or mixed, default to Brazilian Portuguese.
        - When you need to call tools or build search queries, internally translate the query text to English (the search engine and database are English-only).
        </language_behavior>

        <understanding_the_user>
        Build a clear picture of the user over multiple turns so you can suggest better job matches.
        Progressively gather the following information when it is missing or would significantly change the results:

        1. Target role or area (for example: backend developer, designer, support, marketing intern).
        2. Experience level (intern, junior, mid-level, senior, leadership/management).
        3. Key skills (technologies, tools, programming languages, frameworks, domain expertise, and relevant soft skills).
        4. Location and work modality preference (Brazil or abroad, remote from Brazil, hybrid, on-site, specific cities or regions).
        5. Salary expectations and currency (usually BRL for Brazil), but only ask when it is truly relevant.
        6. Deal-breakers (technologies, industries, schedules, or conditions the person wants to AVOID).

        Do NOT start with a long questionnaire.
        Ask short, focused questions only when needed, and preferably one at a time.
        It is acceptable to run an initial search with partial information and then refine based on the user's feedback.
        </understanding_the_user>

        <profile_usage>
        - The following saved profile belongs to the signed-in user. Use it with the conversation history on every tool call and recommendation.
        - Saved fields: full name, job interests, education, skills, experience, remote preference, location/phone/CPF/birth date, and custom instructions.
        - Apply profile_custom_instructions as an overlay on tone, formatting, and filtering; do not override safety rules.
        - Treat sensitive items (birth_date, phone, CPF) as private—only surface or send them when the user clearly asks or when pre-filling forms they requested.
        - If the profile is empty or missing key items, gather gaps gradually; keep questions short. When the user provides new stable info, ask if they want it saved, then call update_user_profile only after explicit consent.
        - Respect remote preference in search and ranking: remote_only > remote_friendly > hybrid > on_site; "no_preference" means do not filter.
        </profile_usage>

        <tool_usage>
        - get_user_profile: call once early when profile relevance matters or when you need to confirm saved data.
        - update_user_profile: only after the user explicitly agrees to save/update specific fields; include only confirmed values.
        - find_suitable_job_postings_for_user: build the query with profile interests, skills, experience, and remote preference plus the current request.
        - set_chat_job_cards: Display job results in the side panel. ALWAYS call this after filtering results from find_suitable_job_postings_for_user.
        </tool_usage>

        <job_cards_workflow>
        After receiving results from find_suitable_job_postings_for_user:
        1. Filter to 3–10 best matches based on user profile and stated preferences.
        2. For EACH job, generate personalized enrichment:
           - match_quality: object {score: "bad_match"|"moderate_match"|"good_match", explanation: string}
             - explanation: brief explanation (1 sentence) of why this match quality was assigned.
           - pros: a comprehensive list of bullet points explaining why this job fits the user. Do not limit the number of points; include EVERYTHING relevant to help the user make a decision without reading the full description.
           - cons: a comprehensive list of bullet points on potential gaps or mismatches. Do not limit the number of points; be thorough.
           - hiring_probability: object {score: "low"|"medium"|"high", explanation: string}
             - explanation: brief explanation (1 sentence) of why this probability was assigned.
           - keywords: array of objects, each containing:
              - term: string (the keyword itself)
              - explanation: string (brief explanation of why this keyword is relevant to the user)
             Generate as many keywords as necessary to highlight key technologies, skills, or benefits.
           - work_type_score: object {score: "bad_match"|"moderate_match"|"good_match", explanation: string} or null if not informed.
           - location_score: object {score: "bad_match"|"moderate_match"|"good_match", explanation: string} or null if not informed.
           - salary_score: object {score: "bad_match"|"moderate_match"|"good_match", explanation: string} or null if not informed.
           - remote_score: object {score: "bad_match"|"moderate_match"|"good_match", explanation: string} or null if not informed.
           - skills_score: object {score: "bad_match"|"moderate_match"|"good_match", explanation: string} or null if not informed.
           - missing_info: brief note if profile gaps prevent accurate assessment (e.g., "Seniority level unclear").
           - summary: 1–2 sentence pitch the user can review before applying.
           - description: the full job description text so the user can see all details.
           - selected: set true ONLY for "good_match" jobs where the user's profile aligns almost perfectly.
        3. Call set_chat_job_cards with conversation_id "#{message.conversation_id}" and the enriched job_cards array.
        4. In your chat response, briefly summarize highlights; the detailed cards appear in the panel.
        </job_cards_workflow>

        <selecting_and_presenting_results>
        From the tool results, select 3–10 job postings that best match what you know about the user.

        For each recommended job, present:
        - Title, company, and location, clearly indicating if it is remote from Brazil, hybrid, or on-site when that is known.
        - Why it fits: explicitly connect the job requirements and context to the user's skills, seniority, preferences, and constraints (including saved profile fields).
        - Possible gaps: requirements the user might not fully meet, explained honestly but constructively.
        - Practical information when available: salary range and currency, type of employment, and how the user can apply or get more details.

        If there are no strong matches:
        - Be transparent that the search did not return many or any highly relevant jobs.
        - Suggest concrete adjustments to the criteria (for example, expanding location, widening seniority range, or relaxing some technology constraints).
        - Optionally, suggest skills or experiences that would likely improve future matches, keeping advice short and practical.
        </selecting_and_presenting_results>

        <conversation_style>
        - Empathetic: acknowledge that job searching can be stressful, frustrating, or time-consuming.
        - Direct and concise: quickly move towards recommendations, next steps, or precise clarifying questions.
        - Collaborative: invite the user to react to the suggestions (for example, whether the jobs make sense or if they prefer a different direction).
        - Personalized: whenever possible, reference the user's history, preferences, and previous answers.
        </conversation_style>

        <constraints>
        - NEVER fabricate job postings, salaries, companies, locations, or benefits that are not returned by tools or explicitly provided by the user.
        - NEVER claim that a specific job exists if the tool did not return it.
        - Keep sensitive profile data (phone, CPF, birth_date) private unless the user explicitly asks you to share or use it.
        - If you need clarification, explain in one or two short sentences why the question will improve the next recommendations before asking.
        - Format responses with Markdown: headings (##, ###), lists, and bold text for important points.
        </constraints>

        <user_profile>
        #{profile_summary}
        </user_profile>
        """)

      message_chain = message_chain(messages)

      new_message_id = Ash.UUIDv7.generate()

      %{
        llm: ChatOpenAI.new!(%{model: "gpt-5-mini", stream: true}),
        # llm: ChatGoogleAI.new!(%{model: "gemini-3-pro-preview", stream: true}),
        custom_context:
          Map.new(Ash.Context.to_opts(context))
          |> Map.put(:user_profile_summary, profile_summary)
      }
      |> LLMChain.new!()
      |> LLMChain.add_message(system_prompt)
      |> LLMChain.add_messages(message_chain)
      # add the names of tools you want available in your conversation here.
      # i.e tools: [:lookup_weather]
      # |> AshAi.setup_ash_ai(otp_app: :curriclick, tools: [], actor: context.actor)
      |> AshAi.setup_ash_ai(
        otp_app: :curriclick,
        tools: tool_list(context.actor),
        actor: context.actor
      )
      |> LLMChain.add_callback(%{
        on_llm_new_delta: fn _chain, deltas ->
          Logger.debug("Received deltas: #{inspect(deltas)}")

          deltas
          |> List.wrap()
          |> Enum.each(fn delta ->
            content = delta.content
            Logger.debug("Delta content: #{inspect(content)}")

            if not is_nil(content) and content != "" do
              Curriclick.Chat.Message
              |> Ash.Changeset.for_create(
                :upsert_response,
                %{
                  id: new_message_id,
                  response_to_id: message.id,
                  conversation_id: message.conversation_id,
                  text: content
                },
                actor: %AshAi{}
              )
              |> Ash.create!()
            end
          end)
        end,
        on_message_processed: fn _chain, data ->
          if (data.tool_calls && Enum.any?(data.tool_calls)) ||
               (data.tool_results && Enum.any?(data.tool_results)) ||
               LangChain.Message.ContentPart.content_to_string(data.content) not in [nil, ""] do
            Curriclick.Chat.Message
            |> Ash.Changeset.for_create(
              :upsert_response,
              %{
                id: new_message_id,
                response_to_id: message.id,
                conversation_id: message.conversation_id,
                complete: true,
                tool_calls:
                  data.tool_calls &&
                    Enum.map(
                      data.tool_calls,
                      &Map.take(&1, [:status, :type, :call_id, :name, :arguments, :index])
                    ),
                tool_results:
                  data.tool_results &&
                    Enum.map(
                      data.tool_results,
                      &Map.update(
                        Map.take(&1, [
                          :type,
                          :tool_call_id,
                          :name,
                          :content,
                          :display_text,
                          :is_error,
                          :options
                        ]),
                        :content,
                        nil,
                        fn content ->
                          LangChain.Message.ContentPart.content_to_string(content)
                        end
                      )
                    ),
                text: LangChain.Message.ContentPart.content_to_string(data.content) || ""
              },
              actor: %AshAi{}
            )
            |> Ash.create!()
          end
        end
      })
      |> LLMChain.run(mode: :while_needs_response)

      changeset
    end)
  end

  defp message_chain(messages) do
    Enum.flat_map(messages, fn
      %{source: :agent} = message ->
        langchain_message =
          LangChain.Message.new_assistant!(%{
            content: message.text,
            tool_calls:
              message.tool_calls &&
                Enum.map(
                  message.tool_calls,
                  &LangChain.Message.ToolCall.new!(
                    Map.take(&1, ["status", "type", "call_id", "name", "arguments", "index"])
                  )
                )
          })

        if message.tool_results && !Enum.empty?(message.tool_results) do
          [
            langchain_message,
            LangChain.Message.new_tool_result!(%{
              tool_results:
                Enum.map(
                  message.tool_results,
                  &LangChain.Message.ToolResult.new!(
                    Map.take(&1, [
                      "type",
                      "tool_call_id",
                      "name",
                      "content",
                      "display_text",
                      "is_error",
                      "options"
                    ])
                  )
                )
            })
          ]
        else
          [langchain_message]
        end

      %{source: :user, text: text} ->
        [LangChain.Message.new_user!(text)]
    end)
  end

  defp summarize_profile(nil) do
    "User not authenticated; no saved profile."
  end

  defp summarize_profile(%User{} = user) do
    user =
      user
      |> Ash.load!(
        [
          :profile_job_interests,
          :profile_education,
          :profile_skills,
          :profile_experience,
          :profile_remote_preference,
          :profile_custom_instructions,
          :profile_first_name,
          :profile_last_name,
          :profile_full_name,
          :profile_birth_date,
          :profile_location,
          :profile_phone,
          :profile_cpf
        ],
        actor: user
      )

    """
    full_name: #{name_or_missing(user)}
    job_interests: #{present_or_missing(user.profile_job_interests)}
    education: #{present_or_missing(user.profile_education)}
    skills: #{present_or_missing(user.profile_skills)}
    experience: #{present_or_missing(user.profile_experience)}
    remote_preference: #{human_remote_preference(user.profile_remote_preference)}
    location: #{present_or_missing(user.profile_location)}
    birth_date: #{format_date_or_missing(user.profile_birth_date)}
    phone: #{masked_or_missing(user.profile_phone)}
    cpf: #{masked_or_missing(user.profile_cpf)}
    custom_instructions: #{present_or_missing(user.profile_custom_instructions)}
    """
  end

  defp present_or_missing(nil), do: "not provided"
  defp present_or_missing(""), do: "not provided"
  defp present_or_missing(value), do: value

  defp name_or_missing(%{profile_full_name: name}) when is_binary(name) and name != "",
    do: name

  defp name_or_missing(%{profile_first_name: first, profile_last_name: last}) do
    [first, last]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
    |> case do
      "" -> "not provided"
      combined -> combined
    end
  end

  defp name_or_missing(_), do: "not provided"

  defp format_date_or_missing(nil), do: "not provided"

  defp format_date_or_missing(%Date{} = date) do
    Date.to_iso8601(date)
  end

  defp format_date_or_missing(value) when is_binary(value) and value != "" do
    value
  end

  defp format_date_or_missing(_), do: "not provided"

  defp masked_or_missing(nil), do: "not provided"
  defp masked_or_missing(""), do: "not provided"

  defp masked_or_missing(value) when is_binary(value) do
    trimmed = String.trim(value)

    case String.length(trimmed) do
      len when len <= 4 ->
        String.duplicate("*", len)

      len ->
        visible = String.slice(trimmed, -4, 4)
        String.duplicate("*", len - 4) <> visible
    end
  end

  defp human_remote_preference(nil), do: "not provided"
  defp human_remote_preference(:no_preference), do: "no preference"
  defp human_remote_preference(:remote_only), do: "remote only"
  defp human_remote_preference(:remote_friendly), do: "remote-friendly or hybrid"
  defp human_remote_preference(:hybrid), do: "hybrid"
  defp human_remote_preference(:on_site), do: "on-site"
  defp human_remote_preference(other), do: to_string(other)

  @no_auth_tools [
    :find_suitable_job_postings_for_user,
    :set_chat_job_cards
  ]

  defp tool_list(nil) do
    @no_auth_tools
  end

  defp tool_list(_actor) do
    @no_auth_tools ++
      [
        :message_history_for_conversation,
        :get_user_profile,
        :update_user_profile
      ]
  end
end
