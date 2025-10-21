defmodule Curriclick.Repo.Migrations.AddVectorEmbeddingToJobListings do
  use Ecto.Migration

  def change do
    alter table(:job_listings) do
      add :description_vector, :vector, size: 1536
    end
  end
end
