defmodule Qblog.Access.Telegram do
  alias Ash.Query
  alias Qblog.Access
  alias Qblog.Access.ExternalIdentity
  alias Qblog.Access.Providers.Telegram, as: TelegramProvider
  alias Qblog.Access.Source
  alias Qblog.Access.Telegram.Bot.Update, as: BotUpdate
  alias Qblog.Accounts.Group
  alias Qblog.Accounts.GroupUserRelation
  alias Qblog.Accounts.User
  alias Qblog.Repo

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
    |> Ash.read(actor: actor, domain: Access)
  end

  def get_bot_update(id, %User{} = actor) do
    Ash.get(BotUpdate, id, actor: actor, domain: Access)
  end

  def list_claimable_sources(%User{} = user, telegram_provider \\ TelegramProvider) do
    with {:ok, identity} <- load_telegram_identity(user),
         {:ok, sources} <- list_pending_sources() do
      Enum.filter(sources, &source_claimable?(&1, identity, telegram_provider))
    end
  end

  def claim_source_with_new_group(
        source_id,
        %User{} = user,
        telegram_provider \\ TelegramProvider
      ) do
    with {:ok, source} <- Ash.get(Source, source_id, authorize?: false, domain: Access),
         :ok <- authorize_pending_source(source),
         {:ok, identity} <- load_telegram_identity(user),
         :ok <- authorize_source_claim(source, identity, telegram_provider) do
      source |> create_group_and_claim_source(user)
    end
  end

  def claim_source_with_existing_group(
        source_id,
        group_id,
        %User{} = user,
        telegram_provider \\ TelegramProvider
      ) do
    with {:ok, source} <- Ash.get(Source, source_id, authorize?: false, domain: Access),
         :ok <- authorize_pending_source(source),
         {:ok, group} <- Ash.get(Group, group_id, authorize?: false, domain: Qblog.Accounts),
         :ok <- authorize_owned_group(group, user),
         {:ok, identity} <- load_telegram_identity(user),
         :ok <- authorize_source_claim(source, identity, telegram_provider) do
      claim_existing_group_source(source, group, user)
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
                    domain: Qblog.Accounts,
                    return_notifications?: true
                  ),
                {:ok, identity, identity_notifications} <-
                  Ash.create(
                    ExternalIdentity,
                    telegram_identity_attrs(provider_user_id, telegram_user, user.id),
                    authorize?: false,
                    domain: Access,
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
      domain: Access
    )
    |> case do
      {:ok, identity} -> Ash.load(identity, [:user], authorize?: false)
      {:error, error} -> {:error, error}
    end
  end

  defp load_external_identity(provider, provider_user_id) do
    ExternalIdentity
    |> Query.filter(provider == ^provider and provider_user_id == ^provider_user_id)
    |> Ash.read_one(authorize?: false, domain: Access, load: [:user])
  end

  defp load_telegram_identity(%{id: user_id}) do
    ExternalIdentity
    |> Query.filter(provider == :telegram and user_id == ^user_id)
    |> Ash.read_one(authorize?: false, domain: Access)
    |> case do
      {:ok, nil} -> {:error, :telegram_identity_not_found}
      result -> result
    end
  end

  defp list_pending_sources do
    Source
    |> Query.filter(provider == :telegram and status == :pending)
    |> Query.sort(inserted_at: :desc)
    |> Ash.read(authorize?: false, domain: Access)
  end

  defp list_active_sources do
    Source
    |> Query.filter(provider == :telegram and status == :active)
    |> Query.sort(inserted_at: :desc)
    |> Ash.read(authorize?: false, domain: Access)
  end

  defp refresh_grant(source, identity, user, telegram_provider) do
    {status, verification_reason} = verify_grant_status(source, identity, telegram_provider)
    log_inactive_grant_verification(status, verification_reason, source, identity, user)

    case upsert_grant(source, identity, user, status) do
      {:ok, grant} ->
        if status == :active do
          with :ok <- ensure_group_member(source, user), do: {:ok, grant}
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
    Logger.warning(
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

  defp ensure_group_member(%{group_id: group_id}, %{id: user_id}) do
    GroupUserRelation
    |> Query.filter(group_id == ^group_id and user_id == ^user_id)
    |> Ash.read_one(authorize?: false, domain: Qblog.Accounts)
    |> case do
      {:ok, nil} -> create_member_relation(group_id, user_id)
      {:ok, _membership} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp create_member_relation(group_id, user_id) do
    case Ash.create(
           GroupUserRelation,
           %{group_id: group_id, type: :member, user_id: user_id},
           authorize?: false,
           domain: Qblog.Accounts
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

  defp authorize_owned_group(%{id: group_id}, %{id: user_id}) do
    GroupUserRelation
    |> Query.filter(group_id == ^group_id and user_id == ^user_id and type == :owner)
    |> Ash.exists(authorize?: false, domain: Qblog.Accounts)
    |> case do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :group_owner_required}
      {:error, error} -> {:error, error}
    end
  end

  defp claim_existing_group_source(source, group, user) do
    case claim_source(source, group, user) do
      {:ok, source, notifications} ->
        Ash.Notifier.notify(notifications)
        {:ok, {group, source}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp create_group_and_claim_source(source, user) do
    case Repo.transaction(fn ->
           with {:ok, group, group_notifications} <- create_group_from_source(source, user),
                {:ok, source, source_notifications} <- claim_source(source, group, user) do
             {group, source, group_notifications ++ source_notifications}
           else
             {:error, error} -> Repo.rollback(error)
           end
         end) do
      {:ok, {group, source, notifications}} ->
        Ash.Notifier.notify(notifications)
        {:ok, {group, source}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp create_group_from_source(source, user) do
    Ash.create(
      Group,
      %{
        description: "Created from Telegram group #{source.title}",
        name: source.title |> group_name_from_source_title()
      },
      action: :create,
      actor: user,
      authorize?: false,
      domain: Qblog.Accounts,
      return_notifications?: true
    )
  end

  defp claim_source(source, group, user) do
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
    |> Ash.Changeset.manage_relationship(:group, group,
      type: :append_and_remove,
      authorize?: false
    )
    |> Ash.update(domain: Access, return_notifications?: true)
  end

  defp group_name_from_source_title(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
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
