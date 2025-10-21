#!/usr/bin/env elixir

# Script to test embedding generation on a sample of job listings
# Usage: mix run scripts/test_embeddings.exs

alias Curriclick.Companies.JobListing

IO.puts("Testing embedding generation on a sample of job listings...")

# Get only a small sample to test within free tier limits
job_listings = JobListing
|> Ash.read!()
|> Enum.take(5)  # Only process 5 items for testing

IO.puts("Found #{length(job_listings)} job listings to process (limited to 5 for free tier)")

if length(job_listings) == 0 do
  IO.puts("No job listings found. Please create some job listings first.")
  System.halt(1)
end

{success_count, error_count} = 
  Enum.with_index(job_listings, 1)
  |> Enum.reduce({0, 0}, fn {job_listing, index}, {success_acc, error_acc} ->
    IO.puts("Processing #{index}/#{length(job_listings)}: #{String.slice(job_listing.job_role_name, 0, 50)}...")
    
    try do
      # Generate embeddings using AshAi's auto-generated action
      result = job_listing
      |> Ash.Changeset.for_update(:ash_ai_update_embeddings, %{})
      |> Ash.update()
      
      case result do
        {:ok, _updated_job} ->
          IO.puts("✅ Success")
          {success_acc + 1, error_acc}
        
        {:error, error} ->
          IO.puts("❌ Failed: #{inspect(error)}")
          {success_acc, error_acc + 1}
      end
      
    rescue
      error ->
        IO.puts("❌ Exception: #{inspect(error)}")
        {success_acc, error_acc + 1}
    end
    
    # Add delay between items to be extra careful with rate limits
    if index < length(job_listings) do
      IO.puts("  Waiting 5 seconds before processing next item...")
      Process.sleep(5_000)
    end
  end)

IO.puts("\n=== Results ===")
IO.puts("✅ Successful: #{success_count}")
IO.puts("❌ Failed: #{error_count}")
IO.puts("📊 Success rate: #{if length(job_listings) > 0, do: round(success_count / length(job_listings) * 100), else: 0}%")
