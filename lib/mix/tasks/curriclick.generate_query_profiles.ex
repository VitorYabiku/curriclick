defmodule Mix.Tasks.Curriclick.GenerateQueryProfiles do
  @moduledoc """
  Generates query profiles (hypothetical resumes) for job listings using OpenAI.
  """
  use Mix.Task
  require Logger
  require Ash.Query

  @shortdoc "Generates query profiles (hypothetical resumes) for job listings using OpenAI"
  def run(_) do
    Mix.Task.run("app.start")
    Logger.configure(level: :info)

    api_url = System.get_env("ELASTIC_API_URL")
    api_key = System.get_env("ELASTIC_API_KEY")
    openai_api_key = System.get_env("OPENAI_API_KEY")

    if is_nil(api_url) or is_nil(api_key) or is_nil(openai_api_key) do
      Mix.raise("ELASTIC_API_URL, ELASTIC_API_KEY, and OPENAI_API_KEY environment variables must be set")
    end

    api_url = String.trim_trailing(api_url, "/")
    index_name = "job-postings"
    
    Logger.info("Fetching job listings from database...")
    # Fetch all listings
    listings = 
      Curriclick.Companies.JobListing 
      |> Ash.Query.load(:company)
      |> Ash.read!()

    Logger.info("Found #{length(listings)} listings. Starting generation...")

    # Concurrency limit (OpenAI rate limits)
    max_concurrency = 5 

    listings
    |> Task.async_stream(fn listing -> 
      generate_and_update(listing, openai_api_key, api_url, api_key, index_name)
    end, max_concurrency: max_concurrency, timeout: 60_000)
    |> Enum.each(fn
      {:ok, :ok} -> :ok
      {:ok, {:error, reason}} -> Logger.error("Failed to process listing: #{inspect(reason)}")
      {:exit, reason} -> Logger.error("Task exited: #{inspect(reason)}")
    end)

    Logger.info("Query profile generation completed.")
  end

  defp generate_and_update(listing, openai_key, es_url, es_key, index) do
    # Check if query_profile is already present (optional optimization, but let's just overwrite for now)
    
    case generate_profile(listing, openai_key) do
      {:ok, profile} ->
        update_elasticsearch(listing.id, profile, es_url, es_key, index)
      {:error, reason} ->
        Logger.error("OpenAI generation failed for #{listing.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_profile(listing, key) do
    url = "https://api.openai.com/v1/chat/completions"
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{key}"}
    ]
    
    # Truncate description if too long to save tokens/money
    description = String.slice(listing.description || "", 0, 3000)
    skills = listing.skills_desc || ""
    company_name = if listing.company, do: listing.company.name, else: "Unknown Company"

    system_prompt = """
    You are an expert career coach and recruiter.
    Given a <job_listing>, create a detailed **query profile** written from a **candidate's perspective**.
    This profile should describe what the perfect candidate is looking for when searching for this exact job.

    # Instructions
    - Focus on aspects a candidate would naturally mention in their resume or job search query.
    - Include key characteristics like:
      - Role and Title
      - Technical Skills and Tools
      - Experience Level
      - Industry and Domain
      - Work preferences (Remote, Salary, Culture)
    - **Format**: Descriptive text without bullet points or sections.
    - **Goal**: The output will be used to match candidates to this job using semantic search.

    # Example
    "Senior Backend Engineer looking for a remote role in a fintech startup working with Elixir, Phoenix, and PostgreSQL. Experienced in building scalable APIs and distributed systems. Valuing engineering excellence, test-driven development, and a collaborative culture. Seeking a salary range of $140k-$180k USD."
    """

    user_prompt = """
    Please generate a query profile for the following job listing:

    <job_listing>
      <title>#{listing.title}</title>
      <company>#{company_name}</company>
      <location>#{listing.location}</location>
      <work_type>#{listing.work_type}</work_type>
      <experience_level>#{listing.formatted_experience_level}</experience_level>
      <salary>
        Min: #{listing.min_salary}
        Max: #{listing.max_salary}
        Currency: #{listing.currency}
      </salary>
      <description>
    #{description}
      </description>
      <skills>
    #{skills}
      </skills>
    </job_listing>
    """

    body = %{
      "model" => "gpt-4o-mini", 
      "messages" => [
        %{"role" => "system", "content" => system_prompt},
        %{"role" => "user", "content" => user_prompt}
      ],
      "max_tokens" => 300
    }

    case Req.post(url, json: body, headers: headers, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        content = get_in(body, ["choices", Access.at(0), "message", "content"])
        {:ok, content}
      {:ok, response} ->
        {:error, "OpenAI status #{response.status}: #{inspect(response.body)}"}
      {:error, error} ->
        {:error, error}
    end
  end

  defp update_elasticsearch(id, profile, url, key, index) do
    doc_url = "#{url}/#{index}/_update/#{id}"
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "ApiKey #{key}"}
    ]
    
    body = %{
      "doc" => %{
        "query_profile" => profile
      }
    }

    case Req.post(doc_url, json: body, headers: headers) do
      {:ok, %{status: 200}} -> 
        Logger.info("Updated profile for #{id}")
        :ok
      {:ok, %{status: 201}} -> 
        :ok 
      {:ok, response} ->
        Logger.error("Failed to update ES for #{id}: #{response.status}")
        {:error, "ES status #{response.status}"}
      {:error, error} ->
        {:error, error}
    end
  end
end
