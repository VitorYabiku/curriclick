defmodule Curriclick.Accounts do
  use Ash.Domain, otp_app: :curriclick, extensions: [AshAi, AshAdmin.Domain, AshPhoenix]

  admin do
    show? true
  end

  tools do
    tool :get_user_profile, Curriclick.Accounts.User, :my_profile do
      description "Fetch the signed-in user's saved profile (interests, education, skills, experience, remote preference, custom instructions)."
    end

    tool :update_user_profile, Curriclick.Accounts.User, :update_profile do
      description "Update the signed-in user's saved profile after they explicitly confirm the change."
    end
  end

  resources do
    resource Curriclick.Accounts.Token

    resource Curriclick.Accounts.User do
      define :update_profile, action: :update_profile
      define :my_profile, action: :my_profile, get_by: [:id]
    end

    resource Curriclick.Accounts.ApiKey
  end
end
