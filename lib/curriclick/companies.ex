defmodule Curriclick.Companies do
  use Ash.Domain, otp_app: :curriclick, extensions: [AshAi, AshAdmin.Domain, AshTypescript.Rpc]

  tools do
    tool :find_suitable_job_postings_for_user,
         Curriclick.Companies.JobListing,
         :find_matching_jobs
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
