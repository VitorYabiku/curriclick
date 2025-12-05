defmodule Mix.Tasks.Curriclick.GenerateJobRequirements do
  use Mix.Task
  require Logger
  require Ash.Query

  @shortdoc "Generates job requirements for listings using LLM"

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, strict: [limit: :integer, concurrency: :integer])
    limit = opts[:limit] || 25
    concurrency = opts[:concurrency] || 5

    Logger.info("Starting generation of job requirements. Limit: #{limit}, Concurrency: #{concurrency}")

    listings =
      Curriclick.Companies.JobListing
      |> Ash.Query.load(:requirements)
      |> Ash.stream!()
      |> Stream.filter(fn listing ->
        # Filter listings that presumably only have basic requirements (or none)
        # We assume that if there are no requirements OTHER than the basic ones, we need to generate.
        basic_reqs = ["Nome Completo", "E-mail", "Telefone", "CPF"]
        existing_questions = Enum.map(listing.requirements, & &1.question)
        
        # Keep if there are NO questions that are NOT in the basic list
        # i.e. empty list, or only basic questions.
        Enum.all?(existing_questions, fn q -> q in basic_reqs end)
      end)
      |> Enum.take(limit)

    Logger.info("Found #{length(listings)} listings needing generated requirements.")

    Task.async_stream(listings, &process_listing/1, max_concurrency: concurrency, timeout: 60_000)
    |> Stream.run()

    Logger.info("Finished generating requirements.")
  end

  defp process_listing(listing) do
    Logger.info("Processing listing: #{listing.title}")

    work_type = listing.formatted_work_type || listing.work_type || "Not specified"
    location = listing.location || "Not specified"
    remote = if listing.remote_allowed, do: "Yes", else: "No"
    skills = if listing.skills_desc && listing.skills_desc != "", do: listing.skills_desc, else: "Not specified explicitly. Please extract skills from the Description above."

    prompt = """
    You are an expert HR assistant. Analyze the following job listing and extract a list of 3-7 specific questions or requirements that a candidate should answer or confirm.

    Focus on:
    - Years of experience with specific technologies mentioned in the description.
    - Certification requirements.
    - Language proficiency (e.g. English level).
    - Specific domain knowledge.
    - Availability for the specific work type or location.

    Note: If skills are not explicitly listed, find them in the Job Description.

    Constraints:
    - DO NOT generate questions for basic personal information (Name, E-mail, Telephone number, CPF) as these are already collected.
    - Output ONLY a valid JSON array of strings.
    - Each string must be a question in Portuguese.

    Job Details:
    - Title: #{listing.title}
    - Work Type: #{work_type}
    - Location: #{location}
    - Remote Allowed: #{remote}

    Description:
    #{String.slice(listing.description || "", 0, 5000)}

    Skills:
    #{skills}
    """

    try do
      llm = LangChain.ChatModels.ChatOpenAI.new!(%{model: "gpt-5-mini"})

      case LangChain.Chains.LLMChain.new!(%{llm: llm})
           |> LangChain.Chains.LLMChain.add_message(LangChain.Message.new_user!(prompt))
           |> LangChain.Chains.LLMChain.run() do
        {:ok, result} ->
          content = LangChain.Message.ContentPart.content_to_string(result.last_message.content)

          if is_binary(content) do
            # Clean up markdown code blocks if present
            json_content =
              content
              |> String.replace(~r/^```json\s*/, "")
              |> String.replace(~r/\s*```$/, "")
              |> String.trim()

            case Jason.decode(json_content) do
              {:ok, questions} when is_list(questions) ->
                Logger.info("Generated #{length(questions)} questions for #{listing.title}")
                save_requirements(listing, questions)

              _ ->
                Logger.error("Failed to parse JSON for listing #{listing.id}: #{content}")
            end
          else
            Logger.error("Model returned non-binary content for listing #{listing.id}: #{inspect(content)}")
          end

        {:error, reason} ->
          Logger.error("LangChain run failed for listing #{listing.id}: #{inspect(reason)}")
      end
    rescue
      e -> Logger.error("Error processing listing #{listing.id}: #{inspect(e)}")
    end
  end

  defp save_requirements(listing, questions) do
    Enum.each(questions, fn question ->
      # Avoid duplication if re-running
      unless Ash.Query.filter(Curriclick.Companies.JobListingRequirement, job_listing_id == ^listing.id and question == ^question) |> Ash.exists?() do
        Curriclick.Companies.JobListingRequirement
        |> Ash.Changeset.for_create(:create, %{question: question, job_listing_id: listing.id})
        |> Ash.create!()
      end
    end)
  end
end
