defmodule Curriclick.Repo.Migrations.EnablePgvectorExtension do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    alter table(:job_listings) do
      add :description_vector, :vector, size: 1536
    end
  end

  def down do
    alter table(:job_listings) do
      remove :description_vector
    end

    execute "DROP EXTENSION IF EXISTS vector"
  end
end
