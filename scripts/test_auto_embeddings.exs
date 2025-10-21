#!/usr/bin/env elixir

# Test automatic embedding generation with after_action strategy
# Usage: mix run scripts/test_auto_embeddings.exs

alias Curriclick.Companies.JobListing

IO.puts("🔍 Testing automatic embedding generation (after_action strategy)")

# Get first 3 job listings for testing
job_listings = JobListing
|> Ash.read!()
|> Enum.take(3)

IO.puts("Selected #{length(job_listings)} job listings for testing:")

Enum.each(job_listings, fn job ->
  IO.puts("- #{job.job_role_name}")
end)

IO.puts("\n🚀 Triggering embedding generation by updating records...")

{success_count, error_count} = 
  Enum.with_index(job_listings, 1)
  |> Enum.reduce({0, 0}, fn {job_listing, index}, {success_acc, error_acc} ->
    IO.puts("\n[#{index}/#{length(job_listings)}] Processing: #{job_listing.job_role_name}")
    
    try do
      # Trigger the after_action embedding generation by doing a simple update
      # We'll just touch the updated_at field by updating with the same values
      result = job_listing
      |> Ash.Changeset.for_update(:update, %{
        job_role_name: job_listing.job_role_name,
        description: job_listing.description
      })
      |> Ash.update()
      
      case result do
        {:ok, updated_job} ->
          IO.puts("  ✅ Update successful - embedding should be generated automatically")
          {success_acc + 1, error_acc}
        
        {:error, error} ->
          IO.puts("  ❌ Update failed: #{inspect(error)}")
          {success_acc, error_acc + 1}
      end
      
    rescue
      error ->
        IO.puts("  ❌ Exception: #{inspect(error)}")
        {success_acc, error_acc + 1}
    end
  end)

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("📊 TEST RESULTS")
IO.puts("✅ Successful updates: #{success_count}")
IO.puts("❌ Failed updates: #{error_count}")

# Check if vectors were actually created
IO.puts("\n🔍 Checking vector creation in database...")

Enum.each(job_listings, fn job ->
  {:ok, result} = Ecto.Adapters.SQL.query(
    Curriclick.Repo, 
    "SELECT description_vector IS NOT NULL as has_vector FROM job_listings WHERE id = $1::uuid", 
    [job.id]
  )
  
  has_vector = result.rows |> List.first() |> List.first()
  status = if has_vector, do: "✅ Has vector", else: "❌ No vector"
  IO.puts("- #{String.slice(job.job_role_name, 0, 40)}: #{status}")
end)

IO.puts("\n✅ Test completed!")