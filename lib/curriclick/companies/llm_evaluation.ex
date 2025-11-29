defmodule Curriclick.Companies.LLMEvaluation do
  use Ash.Resource,
    data_layer: :embedded,
    domain: Curriclick.Companies

  attributes do
    attribute :score, :atom do
      public? true
      allow_nil? false
      constraints one_of: [:bad_match, :moderate_match, :good_match, :low, :medium, :high]
    end

    attribute :explanation, :string do
      public? true
      allow_nil? false
    end
  end
end
