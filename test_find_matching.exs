# Test script for find_matching_jobs action
# Run with: mix run test_find_matching.exs
# (The application needs to be loaded for Ash.Query functions to be available)

IO.puts("\n=== Testing find_matching_jobs action ===\n")

test_description = "Looking for a backend developer role with Elixir and Phoenix"

try do
  results =
    Curriclick.Companies.JobListing
    |> Ash.Query.for_read(:find_matching_jobs, %{ideal_job_description: test_description})
    |> Ash.read!()

  case results do
    [] ->
      IO.puts("⚠️  No jobs found in database")
      IO.puts("\nTo test with data, first create a job listing:")
      IO.puts("  Curriclick.Companies.create_job_listing!(%{")
      IO.puts("    job_role_name: \"Backend Developer\",")
      IO.puts("    description: \"Great Elixir job\",")
      IO.puts("    company_id: <your-company-id>")
      IO.puts("  })")

    jobs ->
      IO.puts("✅ Success! Found #{length(jobs)} job(s)\n")
      job = List.first(jobs)
      IO.puts("=== First Job Result ===")
      IO.puts("Job Role: #{job.job_role_name}")
      IO.puts("Description: #{String.slice(job.description, 0..50)}...")
      IO.puts("\n=== Testing Argument Echo ===")
      IO.puts("ideal_job_description (passed in): #{inspect(test_description)}")
      IO.puts("ideal_job_description (returned):  #{inspect(job.ideal_job_description)}")
      IO.puts("\n✅ Match: #{job.ideal_job_description == test_description}")
      IO.puts("Match Score: #{job.match_score}")
  end
rescue
  e ->
    IO.puts("❌ Error: #{inspect(e)}")
    IO.puts("\nStacktrace:")
    IO.puts(Exception.format_stacktrace(__STACKTRACE__))
end

IO.puts("\n=== Test Complete ===")
