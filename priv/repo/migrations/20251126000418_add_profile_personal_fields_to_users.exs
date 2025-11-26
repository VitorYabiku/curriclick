defmodule Curriclick.Repo.Migrations.AddProfilePersonalFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :profile_first_name, :text
      add :profile_last_name, :text
      add :profile_birth_date, :date
      add :profile_location, :text
      add :profile_cpf, :text
      add :profile_phone, :text
    end
  end
end
