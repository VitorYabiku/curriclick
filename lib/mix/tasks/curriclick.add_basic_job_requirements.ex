defmodule Mix.Tasks.Curriclick.AddBasicJobRequirements do
  use Mix.Task
  require Logger
  require Ash.Query

  @shortdoc "Adds basic personal info requirements to all job listings"
  @basic_requirements ["Nome Completo", "E-mail", "Telefone", "CPF"]

  def run(_args) do
    Mix.Task.run("app.start")

    Logger.info("Starting addition of basic job requirements (bulk)...")

    # 1. Stream all JobListing IDs
    Curriclick.Companies.JobListing
    |> Ash.Query.select([:id])
    |> Ash.stream!(batch_size: 5000)
    |> Stream.flat_map(fn listing ->
      Enum.map(@basic_requirements, fn req ->
        %{question: req, job_listing_id: listing.id}
      end)
    end)
    # 2. Bulk create with upsert to avoid duplicates
    |> Ash.bulk_create(
      Curriclick.Companies.JobListingRequirement,
      :create,
      [
        upsert?: true,
        upsert_identity: :unique_req,
        upsert_fields: [:question],
        batch_size: 5000,
        return_stream?: true,
        return_errors?: true,
        return_records?: false
      ]
    )
    |> Stream.run()

    Logger.info("Finished adding basic requirements.")
  end

  # process_listing is no longer needed
end
