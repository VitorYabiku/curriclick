
api_url = System.get_env("ELASTIC_API_URL")
api_key = System.get_env("ELASTIC_API_KEY")

if is_nil(api_url) or is_nil(api_key) do
  IO.puts("ELASTIC_API_URL or ELASTIC_API_KEY not set")
else
  api_url = String.trim_trailing(api_url, "/")
  # api_url is likely host/index_name
  # We want to get mapping of that index.
  
  headers = [
    {"Content-Type", "application/json"},
    {"Authorization", "ApiKey #{api_key}"}
  ]

  case Req.get("#{api_url}/_mapping", headers: headers) do
    {:ok, %{status: 200, body: body}} -> 
      IO.inspect(body, label: "Mapping")
    {:ok, response} ->
      IO.puts("Failed to get mapping: #{response.status}")
      IO.inspect(response.body)
    {:error, error} ->
      IO.inspect(error, label: "Error")
  end
end
