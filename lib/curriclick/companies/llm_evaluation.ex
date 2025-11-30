defmodule Curriclick.Companies.LLMEvaluation do
  @moduledoc """
  Represents an evaluation score and explanation from the LLM.
  """
  use Ash.Resource,
    data_layer: :embedded,
    domain: Curriclick.Companies

  attributes do
    attribute :score, :atom do
      public? true
      allow_nil? false
      constraints one_of: [
                    :bad_match,
                    :moderate_match,
                    :good_match,
                    :low,
                    :medium,
                    :high,
                    :bad,
                    :moderate,
                    :good
                  ]
    end

    attribute :explanation, :string do
      public? true
      allow_nil? false
    end
  end
end
