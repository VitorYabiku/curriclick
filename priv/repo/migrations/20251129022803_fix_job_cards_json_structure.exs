defmodule Curriclick.Repo.Migrations.FixJobCardsJsonStructure do
  use Ecto.Migration

  def up do
    execute """
    UPDATE conversations
    SET job_cards = ARRAY(
      SELECT
        CASE
          -- Check if match_quality is already an object (if so, keep as is)
          WHEN jsonb_typeof(elem->'match_quality') = 'object' THEN elem
          ELSE
            jsonb_build_object(
              'job_id', elem->'job_id',
              'title', elem->'title',
              'company_name', elem->'company_name',
              'location', elem->'location',
              'description', elem->'description',
              'pros', elem->'pros',
              'cons', elem->'cons',
              'missing_info', elem->'missing_info',
              'summary', elem->'summary',
              'selected', elem->'selected',
              'keywords', elem->'keywords',
              'remote_allowed', elem->'remote_allowed',
              'work_type', elem->'work_type',
              'salary_range', elem->'salary_range',
              'match_quality', jsonb_build_object(
                'score', elem->'match_quality',
                'explanation', elem->'match_quality_explanation'
              ),
              'hiring_probability', jsonb_build_object(
                'score', elem->'success_probability',
                'explanation', elem->'success_probability_explanation'
              ),
               -- New fields need to be null
              'work_type_score', null,
              'location_score', null,
              'salary_score', null,
              'remote_score', null,
              'skills_score', null
            )
        END
      FROM unnest(job_cards) AS elem
    )
    WHERE job_cards IS NOT NULL AND cardinality(job_cards) > 0;
    """
  end

  def down do
    # No operation
  end
end
