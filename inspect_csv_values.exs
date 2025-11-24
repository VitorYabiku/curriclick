
NimbleCSV.define(MyParser, separator: ",", escape: "\"")

file_path = "priv/repo/postings.csv"

headers =
  file_path
  |> File.stream!()
  |> MyParser.parse_stream(skip_headers: false)
  |> Enum.take(1)
  |> hd()

indices = %{
  "work_type" => Enum.find_index(headers, &(&1 == "work_type")),
  "pay_period" => Enum.find_index(headers, &(&1 == "pay_period")),
  "application_type" => Enum.find_index(headers, &(&1 == "application_type")),
  "formatted_experience_level" => Enum.find_index(headers, &(&1 == "formatted_experience_level")),
  "compensation_type" => Enum.find_index(headers, &(&1 == "compensation_type")),
  "currency" => Enum.find_index(headers, &(&1 == "currency"))
}

IO.inspect(indices, label: "Indices")

file_path
|> File.stream!()
|> MyParser.parse_stream(skip_headers: true)
|> Enum.reduce(%{}, fn row, acc ->
  Enum.reduce(indices, acc, fn {key, index}, acc_inner ->
    value = Enum.at(row, index)
    Map.update(acc_inner, key, MapSet.new([value]), &MapSet.put(&1, value))
  end)
end)
|> Enum.each(fn {key, values} ->
  IO.puts("\nUnique values for #{key}:")
  values |> MapSet.to_list() |> Enum.sort() |> IO.inspect()
end)
