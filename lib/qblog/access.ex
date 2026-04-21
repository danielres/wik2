defmodule Qblog.Access do
  use Ash.Domain,
    otp_app: :qblog,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Ash.Query
  alias Qblog.Access.ExternalIdentity
  alias Qblog.Accounts.User
  alias Qblog.Repo

  require Ash.Query

  admin do
    show? true
  end

  resources do
    resource Qblog.Access.ExternalIdentity do
      define :create_external_identity, action: :create

      define :get_external_identity_by_provider_user_id,
        action: :read,
        get_by: [:provider, :provider_user_id]

      define :upsert_external_identity, action: :upsert
    end

    resource Qblog.Access.Source do
      define :create_source, action: :create

      define :get_source_by_provider_source_id,
        action: :read,
        get_by: [:provider, :provider_source_id]

      define :upsert_pending_source_from_provider, action: :upsert_pending_from_provider
      define :upsert_source, action: :upsert
    end

    resource Qblog.Access.Grant do
      define :create_grant, action: :create
      define :get_grant_by_source_and_user, action: :read, get_by: [:source_id, :user_id]
      define :upsert_grant, action: :upsert
    end
  end

  def find_or_create_identity_from_telegram(%{"sub" => telegram_user_id} = telegram_user) do
    provider_user_id = to_string(telegram_user_id)

    case load_external_identity(:telegram, provider_user_id) do
      {:ok, nil} -> create_user_and_identity(provider_user_id, telegram_user)
      {:ok, identity} -> update_external_identity(identity, telegram_user)
      {:error, error} -> {:error, error}
    end
  end

  def upsert_pending_telegram_source(attrs) do
    attrs
    |> Map.put(:provider, :telegram)
    |> upsert_pending_source_from_provider(authorize?: false)
  end

  defp create_user_and_identity(provider_user_id, telegram_user) do
    case Repo.transaction(fn ->
           with {:ok, user, user_notifications} <-
                  Ash.create(User, %{},
                    action: :create_from_external_identity,
                    authorize?: false,
                    domain: Qblog.Accounts,
                    return_notifications?: true
                  ),
                {:ok, identity, identity_notifications} <-
                  Ash.create(
                    ExternalIdentity,
                    telegram_identity_attrs(provider_user_id, telegram_user, user.id),
                    authorize?: false,
                    domain: __MODULE__,
                    return_notifications?: true
                  ),
                {:ok, identity} <- Ash.load(identity, [:user], authorize?: false) do
             {identity, user_notifications ++ identity_notifications}
           else
             {:error, error} -> Repo.rollback(error)
           end
         end) do
      {:ok, {identity, notifications}} ->
        Ash.Notifier.notify(notifications)
        {:ok, identity}

      {:error, error} ->
        {:error, error}
    end
  end

  defp update_external_identity(identity, telegram_user) do
    identity
    |> Ash.update(telegram_identity_attrs(telegram_user),
      action: :update,
      authorize?: false,
      domain: __MODULE__
    )
    |> case do
      {:ok, identity} -> Ash.load(identity, [:user], authorize?: false)
      {:error, error} -> {:error, error}
    end
  end

  defp load_external_identity(provider, provider_user_id) do
    ExternalIdentity
    |> Query.filter(provider == ^provider and provider_user_id == ^provider_user_id)
    |> Ash.read_one(authorize?: false, domain: __MODULE__, load: [:user])
  end

  defp telegram_identity_attrs(provider_user_id, telegram_user, user_id) do
    telegram_user
    |> telegram_identity_attrs()
    |> Map.put(:provider, :telegram)
    |> Map.put(:provider_user_id, provider_user_id)
    |> Map.put(:user_id, user_id)
  end

  defp telegram_identity_attrs(telegram_user) do
    %{
      avatar_url: telegram_user["picture"],
      display_name: telegram_user |> telegram_display_name(),
      metadata: telegram_user,
      username: telegram_user["preferred_username"]
    }
  end

  defp telegram_display_name(telegram_user) do
    [telegram_user["given_name"], telegram_user["family_name"]]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end
end
