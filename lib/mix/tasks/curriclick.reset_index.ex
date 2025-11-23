defmodule Mix.Tasks.Curriclick.ResetIndex do
  use Mix.Task

  require Logger

  @shortdoc "Deletes and recreates the Elasticsearch index with the correct mapping"
  def run(_) do
    Mix.Task.run("app.start")

    api_url = System.get_env("ELASTIC_API_URL")
    api_key = System.get_env("ELASTIC_API_KEY")

    if is_nil(api_url) or is_nil(api_key) do
      Mix.raise("ELASTIC_API_URL and ELASTIC_API_KEY environment variables must be set")
    end

    api_url = String.trim_trailing(api_url, "/")
    index_url = "#{api_url}/job-postings"
    
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "ApiKey #{api_key}"}
    ]

    # 1. Delete existing index
    Logger.info("Deleting existing index at #{index_url}...")
    case Req.delete(index_url, headers: headers) do
      {:ok, %{status: 200}} -> Logger.info("Index deleted.")
      {:ok, %{status: 404}} -> Logger.info("Index did not exist.")
      {:ok, response} -> Logger.warning("Unexpected response deleting index: #{response.status}")
      {:error, error} -> Mix.raise("Failed to delete index: #{inspect(error)}")
    end

    # 2. Create index with correct mapping
    Logger.info("Creating new index with correct mapping...")
    
    mapping = %{
      "mappings" => %{
        "properties" => %{
          "id" => %{ "type" => "keyword" },
          "company_id" => %{ "type" => "keyword" },
          "title" => %{ "type" => "text" },
          "description" => %{ "type" => "text" },
          "location" => %{ "type" => "text" },
          "skills_desc" => %{ "type" => "text" },
          "remote_allowed" => %{ "type" => "boolean" },
          "work_type" => %{ "type" => "keyword" },
          "formatted_work_type" => %{ "type" => "keyword" },
          "min_salary" => %{ "type" => "double" },
          "max_salary" => %{ "type" => "double" },
          "med_salary" => %{ "type" => "double" },
          "normalized_salary" => %{ "type" => "double" },
          "currency" => %{ "type" => "keyword" },
          "pay_period" => %{ "type" => "keyword" },
          "description_semantic" => %{
            "type" => "semantic_text",
            "inference_id" => ".elser-2-elastic"
          }
        }
      }
    }

    case Req.put(index_url, json: mapping, headers: headers) do
      {:ok, %{status: 200}} -> Logger.info("Index created successfully.")
      {:ok, response} -> Mix.raise("Failed to create index: #{inspect(response.body)}")
      {:error, error} -> Mix.raise("Request failed: #{inspect(error)}")
    end
  end
end
