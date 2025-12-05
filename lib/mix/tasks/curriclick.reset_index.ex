defmodule Mix.Tasks.Curriclick.ResetIndex do
  @moduledoc """
  Deletes and recreates the Elasticsearch index with the correct mapping.
  """
  use Mix.Task

  require Logger

  NimbleCSV.define(CSV, separator: ",", escape: "\"")

  @shortdoc "Deletes and recreates the Elasticsearch index with the correct mapping"
  def run(_) do
    Logger.configure(level: :info)
    Mix.Task.run("app.start")

    api_url = System.get_env("ELASTIC_API_URL")
    api_key = System.get_env("ELASTIC_API_KEY")

    if is_nil(api_url) or is_nil(api_key) do
      Mix.raise("ELASTIC_API_URL and ELASTIC_API_KEY environment variables must be set")
    end

    api_url = String.trim_trailing(api_url, "/")
    index_name = "job-postings"
    _index_url = "#{api_url}/#{index_name}"

    _headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "ApiKey #{api_key}"}
    ]

    mapping = %{
      "settings" => %{
        # "index.default_pipeline" => pipeline_name, # Disabled for now
        "analysis" => %{
          "analyzer" => %{
            "html_english" => %{
              "type" => "custom",
              "tokenizer" => "standard",
              "char_filter" => ["html_strip"],
              "filter" => ["lowercase", "english_stop"]
            }
          },
          "filter" => %{
            "english_stop" => %{
              "type" => "stop",
              "stopwords" => "_english_"
            }
          }
        }
      },
      "mappings" => %{
        "properties" => %{
          "id" => %{"type" => "keyword"},
          "company_id" => %{"type" => "keyword"},
          "title" => %{
            "type" => "text",
            "analyzer" => "html_english",
            "copy_to" => ["description_semantic", "title_semantic"]
          },
          "title_semantic" => %{
            "type" => "semantic_text",
            "inference_id" => ".elser-2-elastic"
          },
          "description" => %{
            "type" => "text",
            "analyzer" => "html_english",
            "copy_to" => ["description_semantic", "description_individual_semantic"]
          },
          "description_individual_semantic" => %{
            "type" => "semantic_text",
            "inference_id" => ".elser-2-elastic"
          },
          "location" => %{"type" => "text"},
          "skills_desc" => %{
            "type" => "text",
            "analyzer" => "html_english",
            "copy_to" => ["description_semantic", "skills_desc_semantic"]
          },
          "skills_desc_semantic" => %{
            "type" => "semantic_text",
            "inference_id" => ".elser-2-elastic"
          },
          "remote_allowed" => %{"type" => "boolean"},
          "work_type" => %{"type" => "keyword"},
          "min_salary" => %{"type" => "double"},
          "max_salary" => %{"type" => "double"},
          "med_salary" => %{"type" => "double"},
          "normalized_salary" => %{"type" => "double"},
          "currency" => %{"type" => "keyword"},
          "pay_period" => %{"type" => "keyword"},
          "description_semantic" => %{
            "type" => "semantic_text",
            "inference_id" => ".elser-2-elastic"
          },
          "query_profile" => %{
            "type" => "text",
            "analyzer" => "html_english",
            "copy_to" => "query_profile_semantic"
          },
          "query_profile_semantic" => %{
            "type" => "semantic_text",
            "inference_id" => ".elser-2-elastic"
          }
        }
      }
    }

    # Save mapping to file
    File.write!("job_posting_index_payload.json", Jason.encode!(mapping, pretty: true))
    Logger.info("Saved index payload to job_posting_index_payload.json")

    # 5. Reindex data
    Logger.info("Starting data export to CSV...")

    csv_headers = [
      "id", "company_id", "title", "description", "location", "skills_desc",
      "remote_allowed", "work_type", "min_salary", "max_salary", "med_salary",
      "normalized_salary", "currency", "pay_period"
    ]

    file = File.open!("remaining_job_postings.csv", [:write, :utf8])
    IO.write(file, CSV.dump_to_iodata([csv_headers]))

    offset = 21364
    # Batch size for stream
    batch_size = 1000

    Curriclick.Companies.JobListing
    |> Ash.Query.sort(:id)
    |> Ash.stream!(batch_size: batch_size)
    |> Stream.drop(offset)
    |> Enum.each(fn listing ->
      row = [
        listing.id,
        listing.company_id,
        listing.title,
        listing.description,
        listing.location,
        listing.skills_desc,
        listing.remote_allowed,
        listing.work_type,
        listing.min_salary,
        listing.max_salary,
        listing.med_salary,
        listing.normalized_salary,
        listing.currency,
        listing.pay_period
      ]
      IO.write(file, CSV.dump_to_iodata([row]))
    end)

    File.close(file)
    Logger.info("Data export completed.")
  end
end
