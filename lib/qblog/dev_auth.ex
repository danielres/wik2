defmodule Qblog.DevAuth do
  alias Qblog.Accounts
  alias Qblog.Accounts.User

  require Ash.Query

  @superadmin_email "dev-superadmin@local.dev"

  def list_sign_in_users do
    User
    |> Ash.read(authorize?: false, domain: Accounts)
    |> case do
      {:ok, users} -> {:ok, Enum.sort_by(users, &user_sort_key/1)}
      {:error, error} -> {:error, error}
    end
  end

  def sign_in_user(user_id) when is_binary(user_id) do
    case load_user_by_id(user_id) do
      {:ok, nil} -> {:error, :user_not_found}
      {:ok, user} -> {:ok, user}
      {:error, error} -> {:error, error}
    end
  end

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

  defp load_user_by_id(user_id) do
    User
    |> Ash.Query.filter(id == ^user_id)
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

  defp user_sort_key(user) do
    {role_sort_value(user.role), normalized_email(user.email), user.id}
  end

  defp role_sort_value(:superadmin), do: 0
  defp role_sort_value(_role), do: 1

  defp normalized_email(nil), do: "~"
  defp normalized_email(email), do: email |> to_string() |> String.downcase()
end
