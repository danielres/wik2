defmodule Qblog.Accounts do
  use Ash.Domain, otp_app: :qblog, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Qblog.Accounts.Token
    resource Qblog.Accounts.User

    resource Qblog.Accounts.Group do
      define :get_group_by_name, action: :read, get_by_identity: :unique_name
    end
  end

  def group_name_to_id(group_name) do
    case get_group_by_name(group_name) do
      {:ok, %{id: id}} -> id
      {:error, _reason} -> nil
    end
  end
end
