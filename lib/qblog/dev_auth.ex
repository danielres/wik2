defmodule Qblog.DevAuth do
  alias Qblog.Accounts
  alias Qblog.Accounts.User

  require Ash.Query

  @superadmin_email "dev-superadmin@local.dev"

  def sign_in_superadmin do
    case load_user_by_email(@superadmin_email) do
      {:ok, nil} -> create_superadmin()
      {:ok, %{role: :superadmin} = user} -> {:ok, user}
      {:ok, _user} -> {:error, :dev_superadmin_role_mismatch}
      {:error, error} -> {:error, error}
    end
  end

  defp load_user_by_email(email) do
    User
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one(authorize?: false, domain: Accounts)
  end

  defp create_superadmin do
    Ash.create(
      User,
      %{email: @superadmin_email, role: :superadmin},
      action: :create_dev_user,
      authorize?: false,
      domain: Accounts
    )
  end
end
