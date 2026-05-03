defmodule WikWeb.ErrorTrackerContext do
  @moduledoc false

  import Ash.Expr
  require Ash.Query

  alias Wik.Accounts
  alias Wik.Accounts.GroupUserRelation
  alias Wik.Accounts.User
  alias Wik.Scope

  def set(conn_or_socket) do
    conn_or_socket
    |> build()
    |> ErrorTracker.set_context()

    conn_or_socket
  end

  def build(%{assigns: assigns}) when is_map(assigns) do
    user = assigns[:current_user]
    scope = assigns[:current_scope]

    %{
      user: user_context(user),
      tenant: tenant_context(scope),
      membership_type: membership_type(user, scope)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  def build(_value), do: %{}

  defp user_context(nil), do: nil

  defp user_context(%User{} = user) do
    %{
      id: user.id,
      username: to_string(user),
      email: user.email && to_string(user.email),
      role: Atom.to_string(user.role)
    }
  end

  defp tenant_context(%Scope{tenant: tenant}), do: tenant_context(tenant)
  defp tenant_context(%{tenant: tenant}), do: tenant_context(tenant)
  defp tenant_context(nil), do: nil

  defp tenant_context(%{id: id, name: name}) do
    %{
      id: id,
      name: name
    }
  end

  defp tenant_context(group_name) when is_binary(group_name) do
    %{
      id: Accounts.group_name_to_id(group_name),
      name: group_name
    }
  end

  defp tenant_context(_tenant), do: nil

  defp membership_type(nil, _scope), do: nil
  defp membership_type(_user, nil), do: nil

  defp membership_type(%User{id: user_id}, %Scope{tenant: tenant}) do
    membership_type_for(user_id, tenant)
  end

  defp membership_type(%User{id: user_id}, %{tenant: tenant}) do
    membership_type_for(user_id, tenant)
  end

  defp membership_type(_user, _scope), do: nil

  defp membership_type_for(_user_id, nil), do: nil

  defp membership_type_for(user_id, tenant) do
    case Accounts.tenant_to_group_id(tenant) do
      nil ->
        nil

      group_id ->
        GroupUserRelation
        |> Ash.Query.filter(expr(user_id == ^user_id and group_id == ^group_id))
        |> Ash.Query.set_context(%{private?: true})
        |> Ash.read_one(authorize?: false, domain: Accounts)
        |> case do
          {:ok, %{type: type}} -> Atom.to_string(type)
          _ -> nil
        end
    end
  end
end
