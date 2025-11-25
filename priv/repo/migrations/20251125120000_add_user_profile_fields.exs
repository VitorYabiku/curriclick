defmodule Curriclick.Repo.Migrations.AddUserProfileFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :profile_job_interests, :text
      add :profile_education, :text
      add :profile_skills, :text
      add :profile_experience, :text
      add :profile_remote_preference, :text
      add :profile_custom_instructions, :text
    end
  end
end
