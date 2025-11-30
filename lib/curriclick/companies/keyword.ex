defmodule Curriclick.Companies.Keyword do
  @moduledoc """
  Represents a keyword extracted from a job listing.
  """
  use Ash.Resource,
    data_layer: :embedded,
    domain: Curriclick.Companies

  attributes do
    attribute :term, :string do
      public? true
      allow_nil? false
    end

    attribute :explanation, :string do
      public? true
      allow_nil? false
    end
  end
end
