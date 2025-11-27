defmodule Curriclick.Companies do
  use Ash.Domain, otp_app: :curriclick, extensions: [AshAi, AshAdmin.Domain, AshTypescript.Rpc]

  tools do
    tool :find_suitable_job_postings_for_user,
         Curriclick.Companies.JobListing,
         :find_matching_jobs do
      description "Search job postings using the user's request plus saved profile (interests, skills, experience, location, remote preference, custom instructions). Always include profile_context and profile_remote_preference when available."
    end

    tool :set_chat_job_cards,
         Curriclick.Companies.JobListing,
         :set_chat_job_cards do
      description "Display filtered job cards in the chat UI side panel. Call after find_suitable_job_postings_for_user with enriched data (pros, cons, success_probability). Requires conversation_id from current context."
    end
  end

  admin do
    show? true
  end

  typescript_rpc do
    resource Curriclick.Companies.JobListing do
      rpc_action :list_job_listings, :read
      rpc_action :get_job_listing, :read
      rpc_action :find_matching_jobs, :find_matching_jobs
    end

    resource Curriclick.Companies.Company do
      rpc_action :list_companies, :read
    end
  end

  resources do
    resource Curriclick.Companies.Company
    resource Curriclick.Companies.JobListing
    resource Curriclick.Companies.JobApplication

    resource Curriclick.Companies.JobListing do
      define :find_matching_jobs, action: :find_matching_jobs
    end
  end
end
