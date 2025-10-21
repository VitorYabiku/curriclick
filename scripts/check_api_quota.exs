#!/usr/bin/env elixir

# Script to check OpenAI API quota and usage
# Usage: mix run scripts/check_api_quota.exs

api_key = System.get_env("OPENAI_API_KEY")

if is_nil(api_key) do
  IO.puts("❌ OPENAI_API_KEY environment variable not set")
  System.halt(1)
end

IO.puts("Checking OpenAI API quota and usage...")

headers = [
  {"Authorization", "Bearer #{api_key}"},
  {"Content-Type", "application/json"}
]

# Check API key validity with a minimal request
try do
  # Try to get models list (this is a very lightweight request)
  response = Req.get!("https://api.openai.com/v1/models", 
    headers: headers,
    retry: false
  )
  
  case response.status do
    200 ->
      IO.puts("✅ API key is valid")
      models = response.body["data"]
      |> Enum.filter(fn model -> String.contains?(model["id"], "embedding") end)
      |> Enum.take(3)
      
      IO.puts("Available embedding models:")
      Enum.each(models, fn model ->
        IO.puts("  - #{model["id"]}")
      end)
      
      # Note: OpenAI doesn't provide a direct quota endpoint for free tier users
      # The quota info is only available in error responses or usage endpoints for paid users
      IO.puts("\n📊 Quota Information:")
      IO.puts("- Free tier: 3 RPM (requests per minute) limit")
      IO.puts("- To check current usage, try making a small embedding request")
      IO.puts("- If you get a 429 error, wait before making more requests")
      
    401 ->
      IO.puts("❌ Invalid API key")
    429 ->
      IO.puts("⚠️  Rate limit exceeded - wait before making requests")
      if response.body["error"] do
        IO.puts("Error details: #{response.body["error"]["message"]}")
      end
    _status ->
      IO.puts("❌ Unexpected response: #{response.status}")
      IO.puts("Response: #{inspect(response.body)}")
  end
  
rescue
  error ->
    IO.puts("❌ Failed to check API status: #{inspect(error)}")
end

IO.puts("\n💡 Recommendations for free tier usage:")
IO.puts("- Process 1 item every 30+ seconds")
IO.puts("- Use text-embedding-3-small model (cheaper)")
IO.puts("- Keep text lengths reasonable")
IO.puts("- Monitor for 429 (rate limit) errors")