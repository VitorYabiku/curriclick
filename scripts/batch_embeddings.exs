#!/usr/bin/env elixir

# Efficient batch embedding generation script for paid OpenAI plan
# Usage: mix run scripts/batch_embeddings.exs [batch_size]

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

IO.puts("🚀 Batch embedding generation (Paid Plan)")
IO.puts("Batch size: #{batch_size}")

# Get all job listings first
all_job_listings = JobListing |> Ash.read!()

# Check which ones need embeddings by querying the database directly
{:ok, result} = Ecto.Adapters.SQL.query(
  Curriclick.Repo, 
  "SELECT id FROM job_listings WHERE description_vector IS NULL LIMIT $1", 
  [batch_size]
)

job_ids_needing_vectors = result.rows |> Enum.map(fn [id] -> id end)

if length(job_ids_needing_vectors) == 0 do
  IO.puts("✅ All job listings already have embeddings!")
  
  # Show some stats
  {:ok, total_result} = Ecto.Adapters.SQL.query(Curriclick.Repo, "SELECT COUNT(*) FROM job_listings", [])
  {:ok, with_vectors} = Ecto.Adapters.SQL.query(Curriclick.Repo, "SELECT COUNT(*) FROM job_listings WHERE description_vector IS NOT NULL", [])
  
  total_count = total_result.rows |> List.first() |> List.first()
  vector_count = with_vectors.rows |> List.first() |> List.first()
  
  IO.puts("📊 Statistics:")
  IO.puts("- Total job listings: #{total_count}")
  IO.puts("- With embeddings: #{vector_count}")
  
  System.halt(0)
end

# Get the actual job listing records for processing
job_listings = all_job_listings 
|> Enum.filter(fn job -> Enum.any?(job_ids_needing_vectors, fn id -> id == job.id end) end)
|> Enum.take(batch_size)

{:ok, total_without_vectors} = Ecto.Adapters.SQL.query(
  Curriclick.Repo, 
  "SELECT COUNT(*) FROM job_listings WHERE description_vector IS NULL", 
  []
)

remaining_total = total_without_vectors.rows |> List.first() |> List.first()

IO.puts("\n📊 Status:")
IO.puts("- Job listings without embeddings: #{remaining_total}")
IO.puts("- Processing this batch: #{length(job_listings)}")
IO.puts("- Estimated remaining after this batch: #{remaining_total - length(job_listings)}")

IO.puts("\nStarting embedding generation...")

{success_count, error_count} = 
  Enum.with_index(job_listings, 1)
  |> Enum.reduce({0, 0}, fn {job_listing, index}, {success_acc, error_acc} ->
    progress = "#{index}/#{length(job_listings)}"
    IO.puts("[#{progress}] #{String.slice(job_listing.job_role_name, 0, 60)}")
    
    try do
      result = job_listing
      |> Ash.Changeset.for_update(:ash_ai_update_embeddings, %{})
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

remaining_after = remaining_total - success_count
if remaining_after > 0 do
  IO.puts("\n💡 Continue processing:")
  IO.puts("Run: mix run scripts/batch_embeddings.exs #{min(remaining_after, 100)}")
else
  IO.puts("\n🎉 All job listings now have embeddings!")
end