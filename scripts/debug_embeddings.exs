#!/usr/bin/env elixir

# Debug script to test embedding generation
# Usage: mix run scripts/debug_embeddings.exs

alias Curriclick.Companies.JobListing

IO.puts("🔍 Debug: Testing embedding generation...")

# Get first job listing
job_listing = JobListing
|> Ash.read!()
|> List.first()

if is_nil(job_listing) do
  IO.puts("❌ No job listings found!")
  System.halt(1)
end

IO.puts("📝 Testing with job listing:")
IO.puts("- ID: #{job_listing.id}")
IO.puts("- Job Role: #{job_listing.job_role_name}")
IO.puts("- Description: #{String.slice(job_listing.description, 0, 100)}...")

# Check current vector status in database
{:ok, result} = Ecto.Adapters.SQL.query(
  Curriclick.Repo, 
  "SELECT description_vector IS NOT NULL as has_vector FROM job_listings WHERE id = $1", 
  [{:binary, job_listing.id}]
)

has_vector = result.rows |> List.first() |> List.first()
IO.puts("- Current vector status: #{if has_vector, do: "Has vector", else: "No vector"}")

IO.puts("\n🚀 Starting embedding generation...")

try do
  result = job_listing
  |> Ash.Changeset.for_update(:ash_ai_update_embeddings, %{})
  |> Ash.update()
  
  case result do
    {:ok, updated_job} ->
      IO.puts("✅ Success! Embedding generated.")
      
      # Check database again
      {:ok, check_result} = Ecto.Adapters.SQL.query(
        Curriclick.Repo, 
        "SELECT description_vector IS NOT NULL as has_vector FROM job_listings WHERE id = $1", 
        [{:binary, job_listing.id}]
      )
      
      now_has_vector = check_result.rows |> List.first() |> List.first()
      IO.puts("- Vector status after update: #{if now_has_vector, do: "Has vector", else: "No vector"}")
      
      if now_has_vector do
        # Get vector dimensions
        {:ok, dim_result} = Ecto.Adapters.SQL.query(
          Curriclick.Repo, 
          "SELECT array_length(description_vector::float[], 1) as dimensions FROM job_listings WHERE id = $1", 
          [{:binary, job_listing.id}]
        )
        
        dimensions = dim_result.rows |> List.first() |> List.first()
        IO.puts("- Vector dimensions: #{dimensions}")
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

IO.puts("\n✅ Debug test completed!")