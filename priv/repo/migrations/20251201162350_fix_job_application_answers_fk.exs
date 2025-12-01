defmodule Curriclick.Repo.Migrations.FixJobApplicationAnswersFk do
  use Ecto.Migration

  def up do
    drop constraint(:job_application_answers, "job_application_answers_job_application_id_fkey")

    alter table(:job_application_answers) do
      modify :job_application_id, references(:job_applications, type: :uuid, on_delete: :delete_all, name: "job_application_answers_job_application_id_fkey")
    end
  end

  def down do
    drop constraint(:job_application_answers, "job_application_answers_job_application_id_fkey")

    alter table(:job_application_answers) do
      modify :job_application_id, references(:job_applications, type: :uuid, on_delete: :nothing, name: "job_application_answers_job_application_id_fkey")
    end
  end
end
