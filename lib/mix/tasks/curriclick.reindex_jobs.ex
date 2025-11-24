defmodule Mix.Tasks.Curriclick.ReindexJobs do
  use Mix.Task

  require Logger

  @shortdoc "Re-indexes all job listings from Postgres to Elasticsearch"
  def run(_) do
    Mix.Task.run("app.start")

    api_url = System.get_env("ELASTIC_API_URL")
    api_key = System.get_env("ELASTIC_API_KEY")

    if is_nil(api_url) or is_nil(api_key) do
      Mix.raise("ELASTIC_API_URL and ELASTIC_API_KEY environment variables must be set")
    end

    api_url = String.trim_trailing(api_url, "/")

    Logger.info("Fetching job listings from Postgres...")
    
    # Load all job listings
    listings = 
      Curriclick.Companies.JobListing
      |> Ash.Query.load([:company])
      |> Ash.read!()

    Logger.info("Found #{length(listings)} job listings. Starting indexing...")

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "ApiKey #{api_key}"}
    ]

    # Process in parallel chunks
    listings
    |> Task.async_stream(fn job ->
      index_job(job, api_url, headers)
    end, max_concurrency: 10)
    |> Enum.to_list()

    Logger.info("Indexing complete.")
  end

  defp index_job(job, api_url, headers) do
    body = %{
      "id" => job.id,
      "title" => job.title,
      "description" => job.description,
      "company_id" => job.company_id,
      "location" => job.location,
      "skills_desc" => job.skills_desc,
      "remote_allowed" => job.remote_allowed,
      "work_type" => job.work_type,
      "formatted_work_type" => job.formatted_work_type,
      "min_salary" => job.min_salary,
      "max_salary" => job.max_salary,
      "med_salary" => job.med_salary,
      "normalized_salary" => job.normalized_salary,
      "currency" => job.currency,
      "pay_period" => job.pay_period,
      "description_semantic" => job.description
    }

    url = "#{api_url}/job-postings/_doc/#{job.id}"

    case Req.put(url, json: body, headers: headers) do
      {:ok, %{status: status}} when status in 200..201 ->
        Logger.info("Indexed job #{job.id}")
      {:ok, response} ->
        Logger.error("Failed to index job #{job.id}: #{inspect(response.body)}")
      {:error, error} ->
        Logger.error("Request failed for job #{job.id}: #{inspect(error)}")
    end
  end
end
