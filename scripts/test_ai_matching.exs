#!/usr/bin/env elixir

# Test AI matching with current embeddings
# Usage: mix run scripts/test_ai_matching.exs

alias Curriclick.Companies.JobListing

IO.puts("🧪 Testing AI job matching functionality...")
IO.puts("Testing with current embeddings...")

test_description = "Data Science engineer"

try do
  result = JobListing
  |> Ash.Query.for_read(:find_matching_jobs, %{
    ideal_job_description: test_description,
    limit: 10
  })
  |> Ash.read()
  
  case result do
    {:ok, job_listings} ->
      IO.puts("✅ Success! Found #{length(job_listings)} matching jobs")
      
      # Debug: inspect first job to see what fields are loaded
      if length(job_listings) > 0 do
        first_job = List.first(job_listings)
        IO.puts("🔍 Debug: First job structure: #{inspect(Map.keys(first_job))}")
        IO.puts("🔍 Debug: Company field: #{inspect(first_job.company)}")
      end
      
      if length(job_listings) > 0 do
        IO.puts("\n🎯 Top matches:")
        Enum.with_index(job_listings, 1)
        |> Enum.each(fn {job, index} ->
          match_score = Map.get(job, :match_score, "N/A")
          company_name = 
            case job.company do
              %Ash.NotLoaded{} -> "Unknown Company"
              %{name: name} -> name
              nil -> "Unknown Company"
              _ -> "Unknown Company"
            end
          
          IO.puts("#{index}. #{job.job_role_name} at #{company_name}")
          IO.puts("   📊 Match Score: #{match_score}%")
          IO.puts("   📝 #{String.slice(job.description, 0, 100)}...")
          IO.puts("")
        end)
      else
        IO.puts("❌ No matching jobs found")
        IO.puts("This might be because:")
        IO.puts("- No jobs have similar descriptions to your query")  
        IO.puts("- The cosine distance threshold (0.8) is too strict")
        IO.puts("- Not enough embeddings have been generated")
      end
      
    {:error, error} ->
      IO.puts("❌ Query failed: #{inspect(error)}")
  end
  
rescue
  error ->
    IO.puts("❌ Exception: #{inspect(error)}")
    IO.puts("#{Exception.format_stacktrace(__STACKTRACE__)}")
end
