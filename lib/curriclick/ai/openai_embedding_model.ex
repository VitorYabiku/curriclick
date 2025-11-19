defmodule Curriclick.Ai.OpenAiEmbeddingModel do
  use AshAi.EmbeddingModel

  @impl true
  def dimensions(_opts), do: 1536

  @impl true
  def generate(texts, _opts) do
    api_key = System.get_env("OPENAI_API_KEY")

    if is_nil(api_key) do
      {:error, "OPENAI_API_KEY environment variable not set"}
    else
      # Tier 1 plan has 500 RPM limit, so we can be less conservative
      # Process in batches with small delays to stay well under the limit
      # Process up to 10 texts at once
      batch_size = 10
      # 200ms between batches (300 RPM max)
      delay_between_batches_ms = 200

      texts
      |> Enum.chunk_every(batch_size)
      |> Enum.with_index()
      |> Enum.reduce_while({:ok, []}, fn {batch, index}, {:ok, acc_embeddings} ->
        # Add delay between batches to respect rate limits
        if index > 0 do
          Process.sleep(delay_between_batches_ms)
        end

        headers = [
          {"Authorization", "Bearer #{api_key}"},
          {"Content-Type", "application/json"}
        ]

        body = %{
          "input" => batch,
          "model" => "text-embedding-3-small"
        }

        try do
          response =
            Req.post!("https://api.openai.com/v1/embeddings",
              json: body,
              headers: headers
            )

          case response.status do
            200 ->
              batch_embeddings =
                response.body["data"]
                |> Enum.map(fn %{"embedding" => embedding} -> embedding end)

              {:cont, {:ok, acc_embeddings ++ batch_embeddings}}

            # Rate limit exceeded
            429 ->
              IO.puts("Rate limit hit, backing off...")
              # Wait 5 seconds and try again
              Process.sleep(5000)
              {:halt, {:error, "Rate limit exceeded. Please wait and try again."}}

            _status ->
              {:halt, {:error, response.body}}
          end
        rescue
          error ->
            {:halt, {:error, "Request failed: #{inspect(error)}"}}
        end
      end)
    end
  end
end
