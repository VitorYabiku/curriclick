defmodule Curriclick.Accounts do
  use Ash.Domain, otp_app: :curriclick, extensions: [AshAdmin.Domain, AshPhoenix]

  admin do
    show? true
  end

  resources do
    resource Curriclick.Accounts.Token
    resource Curriclick.Accounts.User
    resource Curriclick.Accounts.ApiKey
  end
end
