# Test script to verify ideal_job_description is returned
IO.puts("Testing find_matching_jobs action...")

results = 
  Curriclick.Companies.JobListing
  |> Ash.Query.for_read(:find_matching_jobs, %{ideal_job_description: "Looking for a backend developer role with Elixir"})
  |> Ash.read!()

case results do
  [] -> 
    IO.puts("\n⚠️  No jobs found in database")
    IO.puts("To properly test, create a job first with:")
    IO.puts("  Curriclick.Companies.create_job_listing!(%{...})")
  
  jobs -> 
    job = List.first(jobs)
    IO.puts("\n✅ Success! Found #{length(jobs)} job(s)")
    IO.puts("\n=== First Job Result ===")
    IO.puts("Job Role: #{job.job_role_name}")
    IO.puts("Ideal Job Description (argument echo): #{inspect(job.ideal_job_description)}")
    IO.puts("Match Score: #{job.match_score}")
end
