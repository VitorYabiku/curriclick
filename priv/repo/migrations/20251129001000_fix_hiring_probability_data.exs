defmodule Curriclick.Repo.Migrations.FixHiringProbabilityData do
  use Ecto.Migration

  def up do
    # Update match_quality: very_good_match -> good_match
    execute "UPDATE job_applications SET match_quality = 'good_match' WHERE match_quality = 'very_good_match'"

    # Update hiring_probability from float strings ("0.8") to atoms ("high", "medium", "low")
    # We cast to float to check the value.
    # Logic: >= 0.7 -> high, >= 0.4 -> medium, else -> low
    execute """
    UPDATE job_applications
    SET hiring_probability = CASE
      WHEN hiring_probability ~ '^[0-9.]+$' AND CAST(hiring_probability AS float) >= 0.7 THEN 'high'
      WHEN hiring_probability ~ '^[0-9.]+$' AND CAST(hiring_probability AS float) >= 0.4 THEN 'medium'
      WHEN hiring_probability ~ '^[0-9.]+$' THEN 'low'
      ELSE hiring_probability
    END
    WHERE hiring_probability ~ '^[0-9.]+$'
    """
  end

  def down do
    # Irreversible data loss in conversion, but we can try to map back to some defaults if needed.
    # For now, we leave it as is since we are moving forward.
    :ok
  end
end
