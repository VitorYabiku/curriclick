#!/usr/bin/env bash
set -euo pipefail
set -o noclobber

cd "$(dirname "$0")/.."

MIX_ENV=${MIX_ENV:-dev}

echo "Running conversation delete smoke test in MIX_ENV=${MIX_ENV}"

mix run -e "
alias Curriclick.{Chat, Repo}
alias Curriclick.Accounts.User
import Ecto.Query

user =
  Repo.one(from u in User, limit: 1) ||
    raise \"No users found. Please create a user first.\"

title = \"Delete test \#{DateTime.utc_now() |> DateTime.to_iso8601()}\"

{:ok, convo} = Chat.create_conversation(%{title: title}, actor: user)
IO.puts(\"Created conversation: \#{convo.id}\")

case Chat.delete_conversation(convo, actor: user) do
  :ok ->
    IO.puts(\"Delete succeeded for \#{convo.id}\")

  {:error, _reason} ->
    IO.puts(\"Delete failed\")
    System.halt(1)
end
"
