defmodule Curriclick.Repo.Migrations.FixConversationJobCardsData do
  use Ecto.Migration

  def up do
    # Update job_cards in conversations table
    # Iterate over the array elements, fixing match_quality and success_probability
    execute """
    UPDATE conversations
    SET job_cards = ARRAY(
      SELECT
        jsonb_set(
          jsonb_set(
            elem,
            '{match_quality}',
            CASE
              WHEN elem->>'match_quality' = 'very_good_match' THEN '"good_match"'::jsonb
              ELSE elem->'match_quality'
            END
          ),
          '{success_probability}',
          CASE
            WHEN elem->>'success_probability' ~ '^[0-9.]+$' THEN
                 (CASE
                    WHEN (elem->>'success_probability')::float >= 0.7 THEN '"high"'
                    WHEN (elem->>'success_probability')::float >= 0.4 THEN '"medium"'
                    ELSE '"low"'
                 END)::jsonb
            ELSE elem->'success_probability'
          END
        )
      FROM unnest(job_cards) AS elem
    )
    WHERE job_cards IS NOT NULL
      AND array_length(job_cards, 1) > 0;
    """
  end

  def down do
    :ok
  end
end
