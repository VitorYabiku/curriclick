defmodule Mix.Tasks.Curriclick.ImportCsv do
  @moduledoc """
  Imports job postings from CSV to Postgres.
  """
  use Mix.Task
  require Logger

  NimbleCSV.define(MyParser, separator: ",", escape: "\"")

  require Ash.Query

  @shortdoc "Imports job postings from CSV to Postgres"
  def run(_) do
    Mix.Task.run("app.start")
    
    file_path = "priv/repo/postings.csv"
    
    Logger.info("Starting CSV import from #{file_path}...")
    
    # Read headers first
    headers = 
      file_path 
      |> File.stream!() 
      |> MyParser.parse_stream(skip_headers: false) 
      |> Enum.take(1) 
      |> hd()

    file_path
    |> File.stream!()
    |> MyParser.parse_stream(skip_headers: true)
    |> Stream.map(fn row -> Enum.zip(headers, row) |> Map.new() end)
    |> Stream.with_index()
    |> Enum.each(fn {row, index} ->
      if rem(index, 100) == 0, do: Logger.info("Processing row #{index}...")
      
      import_row(row)
    end)
    
    Logger.info("Import complete.")
  end

  defp import_row(row) do
    # 1. Handle Company
    company_name = 
      case row["company_name"] do
        nil -> "Unknown Company"
        "" -> "Unknown Company"
        name -> String.trim(name)
      end
    
    company =
      case Curriclick.Companies.Company
           |> Ash.Query.filter(name == ^company_name)
           |> Ash.Query.limit(1)
           |> Ash.read_one() do
        {:ok, nil} ->
          # Create new company
          Curriclick.Companies.Company
          |> Ash.Changeset.for_create(:create, %{name: company_name})
          |> Ash.create!()
        {:ok, company} -> company
        {:error, _} -> 
           # Race condition handling (simple retry)
           Curriclick.Companies.Company
           |> Ash.Query.filter(name == ^company_name)
           |> Ash.Query.limit(1)
           |> Ash.read_one!()
      end

    # 2. Handle Job Listing
    
    # Check if job already exists
    original_id = row["job_id"]
    
    existing_job = 
      Curriclick.Companies.JobListing
      |> Ash.Query.filter(original_id == ^original_id)
      |> Ash.Query.limit(1)
      |> Ash.read_one()
      
    case existing_job do
      {:ok, %{}} -> 
        # Logger.info("Job #{original_id} already exists, skipping.")
        :ok
      {:ok, nil} ->
        create_job_listing(row, company, original_id)
      {:error, _} ->
         Logger.error("Error checking for existing job #{original_id}")
    end
  end

  defp create_job_listing(row, company, original_id) do
    # Parse Salaries
    min_salary = parse_decimal(row["min_salary"])
    max_salary = parse_decimal(row["max_salary"])
    med_salary = parse_decimal(row["med_salary"])
    normalized_salary = parse_decimal(row["normalized_salary"])
    
    # Parse numbers
    views = parse_int(row["views"])
    applies = parse_int(row["applies"])
    sponsored = parse_int(row["sponsored"])
    
    # Parse Timestamps
    original_listed_time = parse_float(row["original_listed_time"])
    listed_time = parse_float(row["listed_time"])
    expiry = parse_float(row["expiry"])
    closed_time = parse_float(row["closed_time"])

    # Parse Atom fields (convert empty to nil)
    pay_period = empty_to_nil(row["pay_period"])
    work_type = empty_to_nil(row["work_type"])
    currency = empty_to_nil(row["currency"])
    application_type = empty_to_nil(row["application_type"])
    formatted_experience_level = empty_to_nil(row["formatted_experience_level"])
    
    # Parse Remote Allowed
    remote_allowed = 
      case row["remote_allowed"] do
        "1.0" -> true
        "1" -> true
        _ -> false
      end

    # Create Job Listing
    Curriclick.Companies.JobListing
    |> Ash.Changeset.for_create(:create, %{
      original_id: original_id,
      title: row["title"],
      description: row["description"],
      company_id: company.id,
      location: row["location"],
      remote_allowed: remote_allowed,
      work_type: work_type,
      # formatted_work_type: excluded
      min_salary: min_salary,
      max_salary: max_salary,
      med_salary: med_salary,
      pay_period: pay_period,
      currency: currency,
      views: views,
      applies: applies,
      original_listed_time: original_listed_time,
      listed_time: listed_time,
      expiry: expiry,
      closed_time: closed_time,
      job_posting_url: row["job_posting_url"],
      application_url: row["application_url"],
      application_type: application_type,
      formatted_experience_level: formatted_experience_level,
      skills_desc: row["skills_desc"],
      posting_domain: row["posting_domain"],
      sponsored: sponsored,
      compensation_type: row["compensation_type"],
      normalized_salary: normalized_salary,
      zip_code: row["zip_code"],
      fips: row["fips"]
    })
    |> Ash.create!()
    
  rescue
    e -> Logger.error("Failed to import row: #{inspect(row["job_id"])} - #{inspect(e)}")
  end
  
  defp empty_to_nil(""), do: nil
  defp empty_to_nil(nil), do: nil
  defp empty_to_nil(str), do: str

  defp parse_decimal(""), do: nil
  defp parse_decimal(nil), do: nil
  defp parse_decimal(str) do
    case Decimal.parse(str) do
      {d, _} -> d
      :error -> nil
    end
  end
  
  defp parse_int(""), do: nil
  defp parse_int(nil), do: nil
  defp parse_int(str) do
    case Integer.parse(str) do
      {i, _} -> i
      :error -> nil
    end
  end
  
  defp parse_float(""), do: nil
  defp parse_float(nil), do: nil
  defp parse_float(str) do
     case Float.parse(str) do
       {f, _} -> f
       :error -> nil
     end
  end
end
