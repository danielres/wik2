defmodule Wik.Access.Telegram do
  alias Ash.Query
  alias Wik.Access
  alias Wik.Access.ExternalIdentity
  alias Wik.Access.Providers.Telegram, as: TelegramProvider
  alias Wik.Access.Source
  alias Wik.Access.Telegram.Bot.Update, as: BotUpdate
  alias Wik.Accounts.Space
  alias Wik.Accounts.Membership
  alias Wik.Accounts.User
  alias Wik.Repo

  require Logger
  require Ash.Query

  def create_bot_update(update) do
    update
    |> TelegramProvider.bot_update_attrs_from_update()
    |> Access.create_telegram_bot_update(authorize?: false)
  end

  def find_or_create_identity(%{"sub" => telegram_user_id} = telegram_user) do
    provider_user_id = to_string(telegram_user_id)

    case load_external_identity(:telegram, provider_user_id) do
      {:ok, nil} -> create_user_and_identity(provider_user_id, telegram_user)
      {:ok, identity} -> update_external_identity(identity, telegram_user)
      {:error, error} -> {:error, error}
    end
  end

  def upsert_pending_source(attrs) do
    attrs
    |> Map.put(:provider, :telegram)
    |> Access.upsert_pending_source_from_provider(authorize?: false)
  end

  def list_bot_updates(%User{} = actor) do
    BotUpdate
    |> Query.sort(inserted_at: :desc, update_id: :desc)
    |> Ash.read(actor: actor)
  end

  def get_bot_update(id, %User{} = actor) do
    Ash.get(BotUpdate, id, actor: actor)
  end

  def list_claimable_sources(%User{} = user, telegram_provider \\ TelegramProvider) do
    with {:ok, identity} <- load_telegram_identity(user),
         {:ok, sources} <- list_pending_sources() do
      Enum.filter(sources, &source_claimable?(&1, identity, telegram_provider))
    end
  end

  def claim_source_with_new_space(
        source_id,
        space_attrs,
        %User{} = user,
        telegram_provider \\ TelegramProvider
      ) do
    with {:ok, source} <- Ash.get(Source, source_id, authorize?: false),
         :ok <- authorize_pending_source(source),
         {:ok, identity} <- load_telegram_identity(user),
         :ok <- authorize_source_claim(source, identity, telegram_provider) do
      create_space_and_claim_source(source, space_attrs, identity, user)
    end
  end

  def claim_source_with_existing_space(
        source_id,
        space_id,
        %User{} = user,
        telegram_provider \\ TelegramProvider
      ) do
    with {:ok, source} <- Ash.get(Source, source_id, authorize?: false),
         :ok <- authorize_pending_source(source),
         {:ok, space} <- Ash.get(Space, space_id, authorize?: false),
         :ok <- authorize_owned_space(space, user),
         {:ok, identity} <- load_telegram_identity(user),
         :ok <- authorize_source_claim(source, identity, telegram_provider) do
      claim_existing_space_source(source, space, identity, user)
    end
  end

  def refresh_grants(%User{} = user, telegram_provider \\ TelegramProvider) do
    with {:ok, identity} <- load_telegram_identity(user),
         {:ok, sources} <- list_active_sources() do
      sources
      |> Enum.reduce_while({:ok, []}, fn source, {:ok, grants} ->
        case refresh_grant(source, identity, user, telegram_provider) do
          {:ok, grant} -> {:cont, {:ok, [grant | grants]}}
          {:error, error} -> {:halt, {:error, error}}
        end
      end)
      |> case do
        {:ok, grants} -> {:ok, Enum.reverse(grants)}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp create_user_and_identity(provider_user_id, telegram_user) do
    case Repo.transaction(fn ->
           with {:ok, user, user_notifications} <-
                  Ash.create(User, %{},
                    action: :create_from_external_identity,
                    authorize?: false,
                    return_notifications?: true
                  ),
                {:ok, identity, identity_notifications} <-
                  Ash.create(
                    ExternalIdentity,
                    telegram_identity_attrs(provider_user_id, telegram_user, user.id),
                    authorize?: false,
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
      authorize?: false
    )
    |> case do
      {:ok, identity} -> Ash.load(identity, [:user], authorize?: false)
      {:error, error} -> {:error, error}
    end
  end

  defp load_external_identity(provider, provider_user_id) do
    ExternalIdentity
    |> Query.filter(provider == ^provider and provider_user_id == ^provider_user_id)
    |> Ash.read_one(authorize?: false, load: [:user])
  end

  defp load_telegram_identity(%{id: user_id}) do
    ExternalIdentity
    |> Query.filter(provider == :telegram and user_id == ^user_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :telegram_identity_not_found}
      result -> result
    end
  end

  defp list_pending_sources do
    Source
    |> Query.filter(provider == :telegram and status == :pending)
    |> Query.sort(inserted_at: :desc)
    |> Ash.read(authorize?: false)
  end

  defp list_active_sources do
    Source
    |> Query.filter(provider == :telegram and status == :active)
    |> Query.sort(inserted_at: :desc)
    |> Ash.read(authorize?: false)
  end

  defp refresh_grant(source, identity, user, telegram_provider) do
    {status, verification_reason} = verify_grant_status(source, identity, telegram_provider)
    log_inactive_grant_verification(status, verification_reason, source, identity, user)

    case upsert_grant(source, identity, user, status) do
      {:ok, grant} ->
        if status == :active do
          with :ok <- ensure_space_member(source, user), do: {:ok, grant}
        else
          {:ok, grant}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp verify_grant_status(source, identity, telegram_provider) do
    case telegram_provider.get_chat_member(source.provider_source_id, identity.provider_user_id) do
      {:ok, chat_member} ->
        if TelegramProvider.active_member?(chat_member) do
          {:active, {:telegram_status, chat_member["status"]}}
        else
          {:inactive, {:telegram_status, chat_member["status"]}}
        end

      {:error, error} ->
        {:inactive, {:telegram_error, error}}
    end
  end

  defp log_inactive_grant_verification(:active, _reason, _source, _identity, _user), do: :ok

  defp log_inactive_grant_verification(:inactive, reason, source, identity, user) do
    Logger.info(
      "Telegram access grant verified as inactive " <>
        inspect(%{
          reason: reason,
          provider_source_id: source.provider_source_id,
          provider_user_id: identity.provider_user_id,
          source_id: source.id,
          user_id: user.id
        })
    )
  end

  defp upsert_grant(source, identity, user, status) do
    Access.upsert_grant(
      %{
        external_identity_id: identity.id,
        last_verified_at: DateTime.utc_now(),
        source_id: source.id,
        status: status,
        user_id: user.id
      },
      authorize?: false
    )
  end

  defp ensure_space_member(%{space_id: space_id}, %{id: user_id}) do
    Membership
    |> Query.filter(space_id == ^space_id and user_id == ^user_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> create_member_relation(space_id, user_id)
      {:ok, _membership} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp create_member_relation(space_id, user_id) do
    case Ash.create(
           Membership,
           %{space_id: space_id, type: :member, user_id: user_id},
           authorize?: false
         ) do
      {:ok, _membership} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp source_claimable?(source, identity, telegram_provider) do
    case telegram_provider.get_chat_member(source.provider_source_id, identity.provider_user_id) do
      {:ok, chat_member} -> TelegramProvider.creator?(chat_member)
      {:error, _error} -> false
    end
  end

  defp authorize_source_claim(source, identity, telegram_provider) do
    case telegram_provider.get_chat_member(source.provider_source_id, identity.provider_user_id) do
      {:ok, chat_member} ->
        if TelegramProvider.creator?(chat_member) do
          :ok
        else
          {:error, :telegram_source_claim_requires_creator}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp authorize_pending_source(%{status: :pending}), do: :ok
  defp authorize_pending_source(_source), do: {:error, :pending_source_required}

  defp authorize_owned_space(%{id: space_id}, %{id: user_id}) do
    Membership
    |> Query.filter(space_id == ^space_id and user_id == ^user_id and type == :owner)
    |> Ash.exists(authorize?: false)
    |> case do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :space_owner_required}
      {:error, error} -> {:error, error}
    end
  end

  defp claim_existing_space_source(source, space, identity, user) do
    case Repo.transaction(fn ->
           with {:ok, source, source_notifications} <- claim_source(source, space, user),
                {:ok, _grant, grant_notifications} <- create_owner_grant(source, identity, user) do
             {source, source_notifications ++ grant_notifications}
           else
             {:error, error} -> Repo.rollback(error)
           end
         end) do
      {:ok, {source, notifications}} ->
        Ash.Notifier.notify(notifications)
        {:ok, {space, source}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp create_space_and_claim_source(source, space_attrs, identity, user) do
    case Repo.transaction(fn ->
           with {:ok, space, space_notifications} <- create_space(space_attrs, user),
                {:ok, source, source_notifications} <- claim_source(source, space, user),
                {:ok, _grant, grant_notifications} <- create_owner_grant(source, identity, user) do
             {space, source, space_notifications ++ source_notifications ++ grant_notifications}
           else
             {:error, error} -> Repo.rollback(error)
           end
         end) do
      {:ok, {space, source, notifications}} ->
        Ash.Notifier.notify(notifications)
        {:ok, {space, source}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp create_space(space_attrs, user) do
    Ash.create(
      Space,
      space_attrs,
      action: :create,
      actor: user,
      authorize?: false,
      return_notifications?: true
    )
  end

  defp claim_source(source, space, user) do
    source
    |> Ash.Changeset.for_update(
      :update,
      %{
        "claimed_at" => DateTime.utc_now(),
        "status" => :active
      },
      authorize?: false
    )
    |> Ash.Changeset.manage_relationship(:claimed_by_user, user,
      type: :append_and_remove,
      authorize?: false
    )
    |> Ash.Changeset.manage_relationship(:space, space,
      type: :append_and_remove,
      authorize?: false
    )
    |> Ash.update(return_notifications?: true)
  end

  defp create_owner_grant(source, identity, user) do
    Access.upsert_grant(
      %{
        external_identity_id: identity.id,
        last_verified_at: DateTime.utc_now(),
        source_id: source.id,
        status: :active,
        user_id: user.id
      },
      authorize?: false,
      return_notifications?: true
    )
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
      metadata: telegram_identity_metadata(telegram_user),
      username: telegram_user["preferred_username"]
    }
  end

  # only store necessary fields according to privacy notice (.../privacy.html.heex)
  defp telegram_identity_metadata(telegram_user) do
    %{
      "auth_date" => telegram_user["auth_date"],
      "family_name" => telegram_user["family_name"],
      "given_name" => telegram_user["given_name"],
      "picture" => telegram_user["picture"],
      "preferred_username" => telegram_user["preferred_username"],
      "provider" => "telegram",
      "sub" => telegram_user["sub"]
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp telegram_display_name(telegram_user) do
    [telegram_user["given_name"], telegram_user["family_name"]]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end
end
