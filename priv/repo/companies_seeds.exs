
# ======================================================================
# Populate companies and job listings from priv/repo/postings.csv
# - Creates a Company for each distinct company_name if it doesn't exist
# - Creates the first 5000 JobListing records with title and description
# ======================================================================

defmodule CompaniesCSVSeeder do
  alias Curriclick.Companies.{Company, JobListing}
  require Ash.Query

  # Minimal RFC4180-ish CSV parser supporting quotes, commas, and newlines in fields
  def parse_csv(binary) when is_binary(binary) do
    bin = String.replace(binary, "\r\n", "\n")
    do_parse(bin, [], [], false, []) |> Enum.reverse()
  end

  defp do_parse(<<>>, field, row, _in_q?, rows) do
    # finalize last field/row
    value = IO.iodata_to_binary(Enum.reverse(field))
    row = [value | row] |> Enum.reverse()
    [row | rows]
  end

  defp do_parse(<<?\n, rest::binary>>, field, row, false, rows) do
    value = IO.iodata_to_binary(Enum.reverse(field))
    row = [value | row] |> Enum.reverse()
    do_parse(rest, [], [], false, [row | rows])
  end

  defp do_parse(<<?,, rest::binary>>, field, row, false, rows) do
    value = IO.iodata_to_binary(Enum.reverse(field))
    do_parse(rest, [], [value | row], false, rows)
  end

  # handle quote toggling and escaped quotes inside quoted field
  defp do_parse(<<?", ?", rest::binary>>, field, row, true, rows) do
    # escaped quote inside quotes -> add a single double-quote character
    do_parse(rest, [?" | field], row, true, rows)
  end

  defp do_parse(<<?", rest::binary>>, field, row, in_q?, rows) do
    do_parse(rest, field, row, !in_q?, rows)
  end

  defp do_parse(<<char, rest::binary>>, field, row, in_q?, rows) do
    do_parse(rest, [char | field], row, in_q?, rows)
  end

  def seed_from_csv(path, limit) do
    IO.puts("\nSeeding companies and job listings from #{path} (limit=#{limit})...")
    csv = File.read!(path)
    [header | rows] = parse_csv(csv)

    # Map header names to indices
    header_index = fn name -> Enum.find_index(header, &(&1 == name)) || raise("Missing column: #{name}") end
    idx_company = header_index.("company_name")
    idx_title = header_index.("title")
    idx_desc = header_index.("description")

    rows
    |> Enum.take(limit)
    |> Enum.reduce(0, fn row, acc ->
      company_name = Enum.at(row, idx_company) |> to_string() |> String.trim() |> String.slice(0, 255)
      title = Enum.at(row, idx_title) |> to_string() |> String.trim() |> String.slice(0, 255)
      description = Enum.at(row, idx_desc) |> to_string() |> String.trim() |> String.slice(0, 3000)

      cond do
        company_name == "" or title == "" or description == "" -> acc
        true ->
          company = get_or_create_company(company_name)
          create_job_listing(company.id, title, description)
          acc + 1
      end
    end)
    |> then(fn count -> IO.puts("Inserted up to #{count} job listings from CSV.") end)
  end

  defp get_or_create_company(name) do
    alias Ash.Query

    case Company
         |> Query.for_read(:read, %{})
         |> Query.filter(name == ^name)
         |> Ash.read!() do
      [company | _] -> company
      [] ->
        Company
        |> Ash.Changeset.for_create(:create, %{name: name})
        |> Ash.create!()
    end
  end

  defp create_job_listing(company_id, title, description) do
    JobListing
    |> Ash.Changeset.for_create(:create, %{
      job_role_name: title,
      description: description,
      company_id: company_id
    })
    |> Ash.create!()
  end
end

CompaniesCSVSeeder.seed_from_csv("priv/repo/postings.csv", 5000)
