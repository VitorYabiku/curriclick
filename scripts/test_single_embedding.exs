#!/usr/bin/env elixir

# Script to test embedding generation on a single job listing (free tier safe)
# Usage: mix run scripts/test_single_embedding.exs

alias Curriclick.Companies.JobListing

IO.puts("Testing embedding generation on a single job listing (free tier safe)...")

# Get just one job listing
job_listings = JobListing
|> Ash.read!()
|> Enum.take(1)

IO.puts("Found #{length(job_listings)} job listing to process")

if length(job_listings) == 0 do
  IO.puts("No job listings found. Please create some job listings first.")
  System.halt(1)
end

job_listing = List.first(job_listings)
IO.puts("Processing: #{String.slice(job_listing.job_role_name, 0, 80)}")
IO.puts("Description preview: #{String.slice(job_listing.description, 0, 100)}...")

IO.puts("\nStarting embedding generation...")

try do
  # Generate embeddings using AshAi's auto-generated action
  result = job_listing
  |> Ash.Changeset.for_update(:ash_ai_update_embeddings, %{})
  |> Ash.update()
  
  case result do
    {:ok, updated_job} ->
      IO.puts("✅ Successfully generated embedding!")
      IO.puts("Job listing updated with embedding vector")
      
      # Try to verify the vector was created (if you want to see the first few dimensions)
      if updated_job.description_vector do
        vector_preview = updated_job.description_vector |> Enum.take(5) |> Enum.map(&Float.round(&1, 4))
        IO.puts("Vector preview (first 5 dimensions): #{inspect(vector_preview)}")
        IO.puts("Total vector dimensions: #{length(updated_job.description_vector)}")
      end
    
    {:error, error} ->
      IO.puts("❌ Failed to generate embedding")
      IO.puts("Error: #{inspect(error)}")
  end
  
rescue
  error ->
    IO.puts("❌ Exception while processing")
    IO.puts("Error: #{inspect(error)}")
end

IO.puts("\n✅ Single embedding test completed!")