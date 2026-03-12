defmodule Qblog.Accounts do
  use Ash.Domain, otp_app: :qblog, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Qblog.Accounts.Token
    resource Qblog.Accounts.User
  end
end
