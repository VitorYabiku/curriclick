defmodule Mix.Tasks.Curriclick.GenerateQueryProfiles do
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
    listings = Curriclick.Companies.JobListing |> Ash.read!()

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
    
    case generate_profile(listing.description, openai_key) do
      {:ok, profile} ->
        update_elasticsearch(listing.id, profile, es_url, es_key, index)
      {:error, reason} ->
        Logger.error("OpenAI generation failed for #{listing.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_profile(description, key) do
    url = "https://api.openai.com/v1/chat/completions"
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{key}"}
    ]
    
    # Truncate description if too long to save tokens/money
    truncated_desc = String.slice(description, 0, 5000)

    body = %{
      "model" => "gpt-4o-mini", 
      "messages" => [
        %{"role" => "system", "content" => "You are an expert career coach. Create a hypothetical candidate profile (resume summary) for a candidate who is perfectly qualified for the following job description. Do not include the job description in the output, only the candidate profile. Limit to 150 words."},
        %{"role" => "user", "content" => "Job Description:\n#{truncated_desc}"}
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
