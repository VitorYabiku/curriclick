defmodule Curriclick.Repo.Migrations.UpdateJobApplicationStatusAndAnswers do
  use Ecto.Migration

  def up do
    alter table(:job_applications) do
      add :status, :text, default: "draft", null: false
    end

    alter table(:job_application_answers) do
      modify :answer, :text, null: true
    end
  end

  def down do
    alter table(:job_applications) do
      remove :status
    end

    alter table(:job_application_answers) do
      modify :answer, :text, null: false
    end
  end
end
