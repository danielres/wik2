defmodule WikWeb.TenantContext do
  @moduledoc """
  Builds tenant-scoped UI context for layouts and LiveViews.
  """

  alias AshPhoenix.Form
  alias Wik.Access
  alias Wik.Accounts
  alias Wik.Accounts.User
  alias Wik.Scope

  def build(nil, _space), do: nil
  def build(%User{} = _user, nil), do: nil

  def build(%User{} = user, space) do
    membership =
      case Accounts.get_membership(space, user) do
        {:ok, membership} -> membership
        {:error, _error} -> nil
      end

    %{
      current_membership: membership,
      membership_username_form: membership_username_form(user, membership, space)
    }
  end

  defp membership_username_form(_user, %{username: username}, _space)
       when is_binary(username) and username != "" do
    nil
  end

  defp membership_username_form(user, membership, space)
       when not is_nil(membership) and not is_nil(space) do
    suggested_username =
      case Access.get_user_space_username_suggestion(user, space) do
        {:ok, username} -> username
        {:error, _error} -> nil
      end

    membership
    |> Form.for_update(:set_username, as: "form", scope: %Scope{actor: user, tenant: space})
    |> maybe_validate_username(suggested_username)
    |> Phoenix.Component.to_form()
  end

  defp membership_username_form(_user, _membership, _space), do: nil

  defp maybe_validate_username(form, username) when is_binary(username) and username != "" do
    Form.validate(form, %{"username" => username}, errors: false)
  end

  defp maybe_validate_username(form, _username), do: form
end
