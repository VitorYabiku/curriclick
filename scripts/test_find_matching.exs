# Test script for find_matching_jobs action
# Run with: mix run test_find_matching.exs
# (The application needs to be loaded for Ash.Query functions to be available)

IO.puts("\n=== Testing find_matching_jobs action ===\n")

test_description = "Junior data scientist. Do NOT like working with Kafka"

Curriclick.Companies.JobListing
# |> Ash.calculate!(:test_calculation, args: %{test_argument: 69.4169})

# |> Ash.Query.limit(2)
# # |> Ash.Query.load([match_score: %{ideal_job_description: test_description}])
# |> Ash.Query.load([
#   :description_vector,
#   dummy_test: %{test_argument: 6669},
#   test_calculation: %{test_argument: 69.420}
# ])
# |> Ash.read!()
# |> dbg()

Curriclick.Companies.find_matching_jobs(%{query: test_description, limit: 5})
|> dbg()

# {:ok, %{"results" => []}} ->
#   IO.puts("⚠️  No jobs found in database")
#   IO.puts("\nTo test with data, first create a job listing:")
#   IO.puts("  Curriclick.Companies.create_job_listing!(%{")
#   IO.puts("    job_role_name: \"Backend Developer\",")
#   IO.puts("    description: \"Great Elixir job\",")
#   IO.puts("    company_id: <your-company-id>")
#   IO.puts("  })")
#
# {:ok, %{"results" => jobs} = payload} when is_list(jobs) and jobs != [] ->
#   IO.puts("✅ Success! Found #{length(jobs)} job(s)\n")
#   job = List.first(jobs)
#   IO.puts("=== First Job Result ===")
#   IO.puts("Job Role: #{job["jobRoleName"]}")
#   IO.puts("Description: #{String.slice(job["description"] || "", 0..50)}...")
#   IO.puts("\n=== Testing Argument Echo ===")
#   IO.puts("ideal_job_description (passed in): #{inspect(test_description)}")
#   IO.puts("ideal_job_description (trimmed):  #{inspect(String.trim(test_description))}")
#   IO.puts("Match Score: #{inspect(job["matchScore"])}")
#   IO.puts("Has More?: #{inspect(payload["hasMore"])}")
#   IO.puts("Count: #{inspect(payload["count"])}")
#
# {:error, error} ->
#   IO.puts("❌ Error: #{inspect(error)}")
# end

IO.puts("\n=== Test Complete ===")
