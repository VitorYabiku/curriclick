#!/usr/bin/env elixir

# Test AI matching with current embeddings
# Usage: mix run scripts/test_ai_matching.exs

alias Curriclick.Companies.JobListing

IO.puts("🧪 Testing AI job matching functionality...")
IO.puts("Testing with current embeddings...")
IO.puts("")
IO.puts("📊 Match Score Guide:")
IO.puts("  • Score range: -1.0 to 1.0 (cosine similarity)")
IO.puts("  • 🟢 0.7-1.0: High similarity (85-100%)")
IO.puts("  • 🟡 0.4-0.7: Medium similarity (70-85%)")
IO.puts("  • 🟠 0.0-0.4: Low similarity (50-70%)")
IO.puts("  • 🔴 <0.0: Negative similarity (<50%)")
IO.puts("")

test_description = "Marketing senior specialist"

try do
  result = JobListing
  |> Ash.Query.for_read(:find_matching_jobs, %{
    ideal_job_description: test_description,
    limit: 10
  })
  |> Ash.Query.ensure_selected([:match_score])
  |> Ash.read()
  
  case result do
    {:ok, job_listings} ->
      IO.puts("✅ Success! Found #{length(job_listings)} matching jobs")
      
      # Debug: inspect first job to see what fields are loaded
      if length(job_listings) > 0 do
        first_job = List.first(job_listings)
        IO.puts("🔍 Debug: First job structure: #{inspect(Map.keys(first_job))}")
        IO.puts("🔍 Debug: match_score field: #{inspect(first_job.match_score)}")
        IO.puts("🔍 Debug: match_score type: #{inspect(first_job.match_score |> is_number())}")
        IO.puts("🔍 Debug: Company field: #{inspect(first_job.company)}")
      end
      
      if length(job_listings) > 0 do
        IO.puts("\n🎯 Top matches:")
        Enum.with_index(job_listings, 1)
        |> Enum.each(fn {job, index} ->
          # Handle the case where match_score might not be loaded
          match_score = case Map.get(job, :match_score) do
            %Ash.NotLoaded{} -> "Not Loaded"
            nil -> "N/A"
            score -> score
          end
          
          # Format match score with float and percentage
          score_display = case match_score do
            "N/A" -> "N/A"
            score when is_number(score) ->
              percentage = ((score + 1) / 2 * 100) |> Float.round(1)
              "#{Float.round(score, 3)} (#{percentage}%)"
            _ -> "#{match_score}"
          end
          
          # Color coding based on new -1 to 1 scale
          score_color = case match_score do
            score when is_number(score) and score >= 0.7 -> "🟢"  # Green for high similarity
            score when is_number(score) and score >= 0.4 -> "🟡"  # Yellow for medium similarity  
            score when is_number(score) and score >= 0.0 -> "🟠"  # Orange for low similarity
            score when is_number(score) -> "🔴"                    # Red for negative similarity
            _ -> "⚪"                                               # White for unknown
          end
          
          company_name = 
            case job.company do
              %Ash.NotLoaded{} -> "Unknown Company"
              %{name: name} -> name
              nil -> "Unknown Company"
              _ -> "Unknown Company"
            end
          
          IO.puts("#{index}. #{job.job_role_name} at #{company_name}")
          IO.puts("   #{score_color} Match Score: #{score_display}")
          IO.puts("   📝 #{String.slice(job.description, 0, 100)}...")
          IO.puts("")
        end)
      else
        IO.puts("❌ No matching jobs found")
        IO.puts("This might be because:")
        IO.puts("- No jobs have similar descriptions to your query")  
        IO.puts("- The match score threshold is too strict")
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
