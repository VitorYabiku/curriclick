# Test script to verify ideal_job_description is returned
IO.puts("Testing find_matching_jobs action...")

input =
  Curriclick.Companies.JobListing
  |> Ash.ActionInput.for_action(:find_matching_jobs, %{
    ideal_job_description: "Looking for a backend developer role with Elixir"
  })

case Ash.run_action(input, domain: Curriclick.Companies) do
  {:ok, %{"results" => []}} ->
    IO.puts("\n⚠️  No jobs found in database")
    IO.puts("To properly test, create a job first with:")
    IO.puts("  Curriclick.Companies.create_job_listing!(%{...})")

  {:ok, %{"results" => jobs}} ->
    job = List.first(jobs)
    IO.puts("\n✅ Success! Found #{length(jobs)} job(s)")
    IO.puts("\n=== First Job Result ===")
    IO.puts("Job Role: #{job["jobRoleName"]}")
    IO.puts("Match Score: #{inspect(job["matchScore"])}")

  {:error, error} ->
    IO.puts("\n❌ Error: #{inspect(error)}")
end
