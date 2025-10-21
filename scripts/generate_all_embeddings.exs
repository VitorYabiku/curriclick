#!/usr/bin/env elixir

# Generate embeddings for all job listings using after_action strategy
# Usage: mix run scripts/generate_all_embeddings.exs [batch_size]

alias Curriclick.Companies.JobListing

# Get batch size from command line argument or default to 50
batch_size = case System.argv() do
  [size_str] -> 
    case Integer.parse(size_str) do
      {size, ""} when size > 0 -> size
      _ -> 50
    end
  _ -> 50
end

IO.puts("🚀 Generating embeddings for all job listings")
IO.puts("Strategy: after_action (automatic generation)")
IO.puts("Batch size: #{batch_size}")

# Check current status
{:ok, total_result} = Ecto.Adapters.SQL.query(Curriclick.Repo, "SELECT COUNT(*) FROM job_listings", [])
{:ok, with_vectors} = Ecto.Adapters.SQL.query(Curriclick.Repo, "SELECT COUNT(*) FROM job_listings WHERE description_vector IS NOT NULL", [])

total_count = total_result.rows |> List.first() |> List.first()
vector_count = with_vectors.rows |> List.first() |> List.first()
remaining_count = total_count - vector_count

IO.puts("\n📊 Current Status:")
IO.puts("- Total job listings: #{total_count}")
IO.puts("- With embeddings: #{vector_count}")
IO.puts("- Remaining: #{remaining_count}")

if remaining_count == 0 do
  IO.puts("✅ All job listings already have embeddings!")
  System.halt(0)
end

# Get job listings that need embeddings
{:ok, ids_result} = Ecto.Adapters.SQL.query(
  Curriclick.Repo, 
  "SELECT id FROM job_listings WHERE description_vector IS NULL LIMIT $1", 
  [batch_size]
)

job_ids = ids_result.rows |> Enum.map(fn [id] -> id end)

# Get job listings by ID more efficiently
job_listings = job_ids
|> Enum.map(fn id -> 
  JobListing |> Ash.get!(id)
end)

IO.puts("- Processing this batch: #{length(job_listings)}")
IO.puts("\n⏳ Estimated time: #{length(job_listings) * 0.5} seconds (with Tier 1 rate limiting)")

IO.puts("\nStarting embedding generation...")

{success_count, error_count} = 
  Enum.with_index(job_listings, 1)
  |> Enum.reduce({0, 0}, fn {job_listing, index}, {success_acc, error_acc} ->
    progress = "#{index}/#{length(job_listings)}"
    IO.puts("[#{progress}] #{String.slice(job_listing.job_role_name, 0, 60)}")
    
    try do
      # Trigger embedding generation with a simple update
      result = job_listing
      |> Ash.Changeset.for_update(:update, %{
        job_role_name: job_listing.job_role_name,
        description: job_listing.description
      })
      |> Ash.update()
      
      case result do
        {:ok, _updated_job} ->
          IO.puts("  ✅ Success")
          {success_acc + 1, error_acc}
        
        {:error, error} ->
          IO.puts("  ❌ Failed: #{inspect(error)}")
          {success_acc, error_acc + 1}
      end
      
    rescue
      error ->
        IO.puts("  ❌ Exception: #{inspect(error)}")
        {success_acc, error_acc + 1}
    end
  end)

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("📊 BATCH RESULTS")
IO.puts("✅ Successful: #{success_count}")
IO.puts("❌ Failed: #{error_count}")
success_rate = if length(job_listings) > 0, do: round(success_count / length(job_listings) * 100), else: 0
IO.puts("📈 Success rate: #{success_rate}%")

# Check final status
{:ok, final_with_vectors} = Ecto.Adapters.SQL.query(Curriclick.Repo, "SELECT COUNT(*) FROM job_listings WHERE description_vector IS NOT NULL", [])
final_vector_count = final_with_vectors.rows |> List.first() |> List.first()
final_remaining = total_count - final_vector_count

IO.puts("\n📊 UPDATED STATUS:")
IO.puts("- Total with embeddings: #{final_vector_count}")
IO.puts("- Still remaining: #{final_remaining}")

if final_remaining > 0 do
  IO.puts("\n💡 Continue processing:")
  IO.puts("Run: mix run scripts/generate_all_embeddings.exs #{min(final_remaining, 100)}")
else
  IO.puts("\n🎉 All job listings now have embeddings!")
end