
File.stream!("priv/repo/postings.csv")
|> CSV.decode!(headers: true)
|> Enum.reduce(%{work_type: MapSet.new(), formatted_work_type: MapSet.new(), remote_allowed: MapSet.new()}, fn row, acc ->
  %{
    work_type: MapSet.put(acc.work_type, row["work_type"]),
    formatted_work_type: MapSet.put(acc.formatted_work_type, row["formatted_work_type"]),
    remote_allowed: MapSet.put(acc.remote_allowed, row["remote_allowed"])
  }
end)
|> IO.inspect()
