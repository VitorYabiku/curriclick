#!/usr/bin/env elixir

# Safe batch embedding generation script for free tier
# Processes a small number of job listings with conservative rate limiting
# Usage: mix run scripts/safe_batch_embeddings.exs [batch_size]

alias Curriclick.Companies.JobListing

# Get batch size from command line argument or default to 3
batch_size = case System.argv() do
  [size_str] -> 
    case Integer.parse(size_str) do
      {size, ""} when size > 0 and size <= 10 -> size
      _ -> 3
    end
  _ -> 3
end

IO.puts("🚀 Safe batch embedding generation")
IO.puts("Batch size: #{batch_size} (max 10 for free tier safety)")
IO.puts("Rate limiting: ~40 seconds between requests")

# Get job listings that don't have embeddings yet
# Note: We need to explicitly load the vector field since it might not be selected by default
job_listings = JobListing
|> Ash.read!(load: [])
|> Enum.filter(fn job -> is_nil(Map.get(job, :description_vector)) end)
|> Enum.take(batch_size)

total_count = JobListing |> Ash.read!() |> length()
remaining_count = JobListing 
|> Ash.read!(load: []) 
|> Enum.filter(fn job -> is_nil(Map.get(job, :description_vector)) end) 
|> length()

IO.puts("\n📊 Status:")
IO.puts("- Total job listings: #{total_count}")
IO.puts("- Without embeddings: #{remaining_count}")
IO.puts("- Processing this batch: #{length(job_listings)}")

if length(job_listings) == 0 do
  IO.puts("✅ All job listings already have embeddings!")
  System.halt(0)
end

IO.puts("\n⏰ Estimated time: #{length(job_listings) * 40} seconds")
IO.puts("Starting in 3 seconds...")
Process.sleep(3_000)

{success_count, error_count} = 
  Enum.with_index(job_listings, 1)
  |> Enum.reduce({0, 0}, fn {job_listing, index}, {success_acc, error_acc} ->
    progress = "#{index}/#{length(job_listings)}"
    IO.puts("\n📝 [#{progress}] Processing: #{String.slice(job_listing.job_role_name, 0, 60)}")
    
    try do
      result = job_listing
      |> Ash.Changeset.for_update(:ash_ai_update_embeddings, %{})
      |> Ash.update()
      
      case result do
        {:ok, _updated_job} ->
          IO.puts("   ✅ Success!")
          new_success = success_acc + 1
          
          # Wait between requests (except for the last one)
          if index < length(job_listings) do
            wait_time = 40
            IO.puts("   ⏳ Waiting #{wait_time}s before next request...")
            Process.sleep(wait_time * 1000)
          end
          
          {new_success, error_acc}
        
        {:error, error} ->
          IO.puts("   ❌ Failed: #{inspect(error)}")
          {success_acc, error_acc + 1}
      end
      
    rescue
      error ->
        IO.puts("   ❌ Exception: #{inspect(error)}")
        {success_acc, error_acc + 1}
    end
  end)

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("📊 RESULTS")
IO.puts("✅ Successful: #{success_count}")
IO.puts("❌ Failed: #{error_count}")
success_rate = if length(job_listings) > 0, do: round(success_count / length(job_listings) * 100), else: 0
IO.puts("📈 Success rate: #{success_rate}%")

remaining_after = remaining_count - success_count
if remaining_after > 0 do
  IO.puts("\n💡 Next steps:")
  IO.puts("- #{remaining_after} job listings still need embeddings")
  IO.puts("- Wait a few minutes, then run this script again")
  IO.puts("- Use: mix run scripts/safe_batch_embeddings.exs #{min(remaining_after, 10)}")
else
  IO.puts("\n🎉 All job listings now have embeddings!")
end