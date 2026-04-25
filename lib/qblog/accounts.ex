defmodule Qblog.Accounts do
  use Ash.Domain,
    otp_app: :qblog,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  admin do
    show? true
  end

  resources do
    resource Qblog.Accounts.Token
    resource Qblog.Accounts.User
    resource Qblog.Accounts.Profile

    resource Qblog.Accounts.Group do
      define :get_group_by_name, action: :read, get_by_identity: :unique_name

      # TODO: filter by actor
      define :list_groups,
        action: :read,
        args: [],
        default_options: [
          query: [sort: [inserted_at: :desc]],
          load: [:author]
        ]
    end

    resource Qblog.Accounts.GroupUserRelation
  end

  require Ash.Query

  alias Qblog.Accounts.Group
  alias Qblog.Accounts.User

  def list_owned_groups(%User{id: user_id}) do
    Group
    |> Ash.Query.filter(exists(memberships, user_id == ^user_id and type == :owner))
    |> Ash.Query.sort(name: :asc)
    |> Ash.read(authorize?: false, domain: __MODULE__)
  end

  def group_name_to_id(group_name) do
    case get_group_by_name(group_name, authorize?: false) do
      {:ok, %{id: id}} -> id
      {:error, _reason} -> nil
    end
  end

  def tenant_to_group_id(%{id: group_id}), do: group_id
  def tenant_to_group_id(group_name) when is_binary(group_name), do: group_name_to_id(group_name)
  def tenant_to_group_id(_), do: nil
end
