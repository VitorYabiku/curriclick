#!/usr/bin/env elixir

# Comprehensive match score validation script
# Tests the semantic matching algorithm with various scenarios
# Usage: mix run scripts/validate_match_scores.exs

alias Curriclick.Companies.JobListing

defmodule MatchScoreValidator do
  @moduledoc """
  Validates that the match score algorithm produces semantically meaningful results.
  """

  def run_test(test_name, query, expected_match_types, limit \\ 10) do
    IO.puts("\n" <> String.duplicate("═", 70))
    IO.puts("TEST: #{test_name}")
    IO.puts(String.duplicate("═", 70))
    IO.puts("🔍 Query: \"#{query}\"")
    IO.puts("📋 Expected Match Types: #{inspect(expected_match_types)}")
    IO.puts("")

    case JobListing
         |> Ash.Query.for_read(:find_matching_jobs, %{
           ideal_job_description: query,
           limit: limit
         })
         |> Ash.read() do
      {:ok, job_listings} ->
        analyze_results(job_listings, expected_match_types, query)

      {:error, error} ->
        IO.puts("❌ Test failed with error: #{inspect(error)}")
        {:error, test_name}
    end
  end

  defp analyze_results(job_listings, expected_match_types, query) do
    if length(job_listings) == 0 do
      IO.puts("⚠️  No results found")
      IO.puts("   This might indicate the cosine distance threshold is too strict")
      {:warning, :no_results}
    else
      IO.puts("✅ Found #{length(job_listings)} matches\n")
      
      # Display top 5 results with detailed analysis
      job_listings
      |> Enum.take(5)
      |> Enum.with_index(1)
      |> Enum.each(fn {job, index} ->
        display_match_result(job, index, query)
      end)

      # Analyze match quality
      scores = extract_scores(job_listings)
      
      if length(scores) > 0 do
        stats = calculate_statistics(scores)
        display_statistics(stats)
        
        # Validate expectations
        validation_result = validate_expectations(
          job_listings, 
          expected_match_types, 
          stats
        )
        
        display_validation_result(validation_result)
        validation_result
      else
        IO.puts("⚠️  No scores available for analysis")
        {:warning, :no_scores}
      end
    end
  end

  defp display_match_result(job, index, _query) do
    match_score = get_match_score(job)
    company_name = get_company_name(job)
    
    score_display = format_score(match_score)
    quality = score_quality(match_score)
    
    IO.puts("""
    #{index}. #{job.job_role_name}
       🏢 Company: #{company_name}
       📊 Match Score: #{score_display} - #{quality}
       📝 Description: #{String.slice(job.description, 0, 200)}...
    """)
  end

  defp get_match_score(job) do
    Map.get(job.calculations, :match_score, Map.get(job, :match_score))
  end

  defp get_company_name(job) do
    case job.company do
      %Ash.NotLoaded{} -> "Unknown"
      %{name: name} when is_binary(name) -> name
      _ -> "Unknown"
    end
  end

  defp format_score(score) when is_number(score) do
    "#{Float.round(score, 3)} (#{Float.round(score * 100, 1)}%)"
  end
  defp format_score(_), do: "N/A"

  defp score_quality(score) when is_number(score) and score >= 0.8, do: "🟢 Excellent"
  defp score_quality(score) when is_number(score) and score >= 0.6, do: "🟡 Good"
  defp score_quality(score) when is_number(score) and score >= 0.4, do: "🟠 Fair"
  defp score_quality(score) when is_number(score) and score >= 0.2, do: "🔴 Poor"
  defp score_quality(score) when is_number(score) and score >= 0.0, do: "⚫ Very Poor"
  defp score_quality(score) when is_number(score), do: "🔵 Opposite"
  defp score_quality(_), do: "⚪ Unknown"

  defp extract_scores(job_listings) do
    job_listings
    |> Enum.map(&get_match_score/1)
    |> Enum.filter(&is_number/1)
  end

  defp calculate_statistics(scores) do
    %{
      count: length(scores),
      avg: Enum.sum(scores) / length(scores),
      max: Enum.max(scores),
      min: Enum.min(scores),
      excellent: Enum.count(scores, &(&1 >= 0.8)),
      good: Enum.count(scores, &(&1 >= 0.6 and &1 < 0.8)),
      fair: Enum.count(scores, &(&1 >= 0.4 and &1 < 0.6)),
      poor: Enum.count(scores, &(&1 >= 0.2 and &1 < 0.4)),
      very_poor: Enum.count(scores, &(&1 >= 0.0 and &1 < 0.2)),
      opposite: Enum.count(scores, &(&1 < 0.0))
    }
  end

  defp display_statistics(stats) do
    IO.puts("""
    
    📊 Score Statistics:
       Count:    #{stats.count} results
       Average:  #{Float.round(stats.avg, 3)} (#{Float.round(stats.avg * 100, 1)}%)
       Range:    #{Float.round(stats.min, 3)} to #{Float.round(stats.max, 3)}
       
       Distribution:
       🟢 Excellent (≥0.8): #{stats.excellent}
       🟡 Good (≥0.6):      #{stats.good}
       🟠 Fair (≥0.4):      #{stats.fair}
       🔴 Poor (≥0.2):      #{stats.poor}
       ⚫ Very Poor (<0.2):  #{stats.very_poor}
       🔵 Opposite (<0.0):  #{stats.opposite}
    """)
  end

  defp validate_expectations(job_listings, expected_types, stats) do
    # Check if top results match expected types
    top_jobs = Enum.take(job_listings, 3)
    
    expectations_met = Enum.any?(top_jobs, fn job ->
      role_lower = String.downcase(job.job_role_name)
      desc_lower = String.downcase(job.description)
      
      Enum.any?(expected_types, fn expected ->
        expected_lower = String.downcase(expected)
        String.contains?(role_lower, expected_lower) or
        String.contains?(desc_lower, expected_lower)
      end)
    end)
    
    score_reasonable = stats.avg >= 0.3 and stats.max >= 0.5
    
    cond do
      expectations_met and score_reasonable ->
        {:pass, "Expectations met: relevant matches found with reasonable scores"}
      
      expectations_met and not score_reasonable ->
        {:warning, "Matches found but scores seem low (avg: #{Float.round(stats.avg, 3)})"}
      
      not expectations_met and score_reasonable ->
        {:fail, "Scores look good but matches don't align with expected types"}
      
      true ->
        {:fail, "Neither expectations nor score quality criteria met"}
    end
  end

  defp display_validation_result({:pass, message}) do
    IO.puts("\n✅ VALIDATION PASSED: #{message}\n")
  end

  defp display_validation_result({:warning, message}) do
    IO.puts("\n⚠️  VALIDATION WARNING: #{message}\n")
  end

  defp display_validation_result({:fail, message}) do
    IO.puts("\n❌ VALIDATION FAILED: #{message}\n")
  end

  def run_exact_match_test() do
    IO.puts("\n" <> String.duplicate("═", 70))
    IO.puts("SPECIAL TEST: Exact Match Validation")
    IO.puts(String.duplicate("═", 70))
    IO.puts("Testing if using exact job titles produces high match scores...")
    IO.puts("")

    # Get a few random jobs to test with
    sample_jobs = JobListing
    |> Ash.Query.limit(5)
    |> Ash.read!()
    |> Enum.filter(fn job -> not is_nil(Map.get(job, :description_vector)) end)
    
    if length(sample_jobs) == 0 do
      IO.puts("⚠️  No jobs with embeddings found for exact match testing")
      {:warning, :no_embeddings}
    else
      results = Enum.map(sample_jobs, fn job ->
        test_exact_match_for_job(job)
      end)
      
      passed = Enum.count(results, &(&1 == :pass))
      total = length(results)
      
      IO.puts("\n" <> String.duplicate("─", 70))
      IO.puts("Exact Match Test Results: #{passed}/#{total} passed")
      
      if passed == total do
        IO.puts("✅ All exact matches scored highly (≥0.8)")
        {:pass, "All exact matches validated"}
      else
        IO.puts("⚠️  Some exact matches had unexpectedly low scores")
        {:warning, "Exact match scores lower than expected"}
      end
    end
  end

  defp test_exact_match_for_job(job) do
    # Use the exact description as the query
    query = job.description
    
    IO.puts("Testing: #{job.job_role_name}")
    IO.puts("   Using exact description as query...")
    
    case JobListing
         |> Ash.Query.for_read(:find_matching_jobs, %{
           ideal_job_description: query,
           limit: 5
         })
         |> Ash.read() do
      {:ok, matches} ->
        # Find this job in the results
        self_match = Enum.find(matches, fn m -> m.id == job.id end)
        
        if self_match do
          score = get_match_score(self_match)
          IO.puts("   Score for self-match: #{format_score(score)}")
          
          if is_number(score) and score >= 0.8 do
            IO.puts("   ✅ Excellent self-match score")
            :pass
          else
            IO.puts("   ⚠️  Self-match score lower than expected")
            :warning
          end
        else
          IO.puts("   ❌ Job not found in its own search results!")
          :fail
        end
        
      {:error, _} ->
        IO.puts("   ❌ Search failed")
        :fail
    end
  end
end

# Main test execution
IO.puts("""
╔════════════════════════════════════════════════════════════════════╗
║          🧪 Match Score Algorithm Validation Suite               ║
╚════════════════════════════════════════════════════════════════════╝

This script validates that the semantic matching algorithm produces
meaningful results by testing various search scenarios.
""")

# Check if embeddings exist
{:ok, with_vectors} = Ecto.Adapters.SQL.query(
  Curriclick.Repo, 
  "SELECT COUNT(*) FROM job_listings WHERE description_vector IS NOT NULL", 
  []
)

vector_count = with_vectors.rows |> List.first() |> List.first()

if vector_count < 5 do
  IO.puts("""
  ⚠️  WARNING: Only #{vector_count} jobs have embeddings!
  
  Please generate more embeddings before running this validation:
    mix run scripts/safe_batch_embeddings.exs 10
  """)
  System.halt(1)
end

IO.puts("✅ Found #{vector_count} jobs with embeddings\n")
IO.puts("Starting validation tests...\n")

# Run test suite
results = [
  # Test 1: Generic software engineering query
  MatchScoreValidator.run_test(
    "Generic Software Engineering",
    "Software Engineer",
    ["software", "engineer", "developer", "programmer", ".net", "java", "python"],
    15
  ),
  
  # Test 2: Specific technology stack
  MatchScoreValidator.run_test(
    "Specific Tech Stack (.NET)",
    ".NET Developer with C# and Azure experience",
    [".net", "c#", "azure", "architect", "developer"],
    10
  ),
  
  # Test 3: Non-technical role (should NOT match technical jobs)
  MatchScoreValidator.run_test(
    "Marketing Role (Non-Technical)",
    "Marketing Manager with social media and content strategy experience",
    ["marketing", "social", "content", "strategy", "manager"],
    10
  ),
  
  # Test 4: Education/Teaching role
  MatchScoreValidator.run_test(
    "Teaching Role",
    "High school teacher with science education background",
    ["teacher", "education", "school", "science", "biological"],
    10
  ),
  
  # Test 5: Finance/Accounting
  MatchScoreValidator.run_test(
    "Finance Role",
    "Accounts Payable specialist with ERP system experience",
    ["accounting", "payable", "finance", "tax", "accounts"],
    10
  ),
  
  # Test 6: Very specific query
  MatchScoreValidator.run_test(
    "Highly Specific Query",
    "Remote QA automation engineer with selenium and python testing frameworks",
    ["qa", "quality", "testing", "automation", "engineer"],
    10
  ),
]

# Run exact match validation
exact_match_result = MatchScoreValidator.run_exact_match_test()

# Summarize results
IO.puts("\n" <> String.duplicate("═", 70))
IO.puts("FINAL SUMMARY")
IO.puts(String.duplicate("═", 70))

all_results = results ++ [exact_match_result]
passed = Enum.count(all_results, fn 
  {:pass, _} -> true
  _ -> false
end)

warnings = Enum.count(all_results, fn
  {:warning, _} -> true
  _ -> false
end)

failed = Enum.count(all_results, fn
  {:fail, _} -> true
  {:error, _} -> true
  _ -> false
end)

total = length(all_results)

IO.puts("""
Total Tests: #{total}
✅ Passed: #{passed}
⚠️  Warnings: #{warnings}
❌ Failed: #{failed}

Pass Rate: #{Float.round(passed / total * 100, 1)}%
""")

if failed == 0 do
  IO.puts("🎉 All validation tests passed or had minor warnings!")
  IO.puts("The match score algorithm appears to be working correctly.")
else
  IO.puts("⚠️  Some tests failed. Review the results above for details.")
  IO.puts("Consider:")
  IO.puts("  • Generating more embeddings")
  IO.puts("  • Adjusting the cosine distance threshold")
  IO.puts("  • Checking if the embedding model is appropriate")
end

IO.puts("""

💡 Next Steps:
  • Review individual test results above for details
  • Try manual queries with: mix run scripts/test_ai_matching.exs "your query"
  • Generate more embeddings if coverage is low
  • Experiment with different threshold values if needed
""")
