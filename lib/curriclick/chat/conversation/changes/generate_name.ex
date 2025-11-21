defmodule Curriclick.Chat.Conversation.Changes.GenerateName do
  use Ash.Resource.Change
  require Ash.Query

  alias LangChain.Chains.LLMChain
  alias LangChain.ChatModels.ChatOpenAI

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      conversation = changeset.data

      messages =
        Curriclick.Chat.Message
        |> Ash.Query.filter(conversation_id == ^conversation.id)
        |> Ash.Query.limit(10)
        |> Ash.Query.select([:text, :source])
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.read!()

      system_prompt =
        LangChain.Message.new_system!("""
        Provide a short name for the current conversation.
        2-8 words, preferring more succinct names.
        RESPOND WITH ONLY THE NEW CONVERSATION NAME.
        """)

      transcript =
        Enum.map_join(messages, "\n\n", fn message ->
          role = if message.source == :agent, do: "Assistant", else: "User"
          "#{role}: #{message.text}"
        end)

      user_message = LangChain.Message.new_user!("Here is the conversation:\n\n#{transcript}")

      %{
        llm: ChatOpenAI.new!(%{model: "gpt-5-mini"}),
        custom_context: Map.new(Ash.Context.to_opts(context)),
        verbose?: true
      }
      |> LLMChain.new!()
      |> LLMChain.add_message(system_prompt)
      |> LLMChain.add_message(user_message)
      |> LLMChain.run(mode: :while_needs_response)
      |> case do
        {:ok,
         %LangChain.Chains.LLMChain{
           last_message: %{content: content}
         }} ->
          Ash.Changeset.force_change_attribute(
            changeset,
            :title,
            LangChain.Message.ContentPart.content_to_string(content)
          )

        {:error, _, error} ->
          {:error, error}
      end
    end)
  end
end
