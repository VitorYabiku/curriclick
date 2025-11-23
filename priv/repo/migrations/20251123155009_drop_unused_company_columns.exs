defmodule Curriclick.Repo.Migrations.DropUnusedCompanyColumns do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      remove :industry
      remove :cnpj
    end
  end
end
