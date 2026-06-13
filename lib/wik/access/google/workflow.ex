defmodule Wik.Access.Google.Workflow do
  alias Ash.Query
  alias Wik.Access
  alias Wik.Access.ExternalIdentity
  alias Wik.Access.Google.EmailRule
  alias Wik.Access.Grant
  alias Wik.Accounts.Membership
  alias Wik.Accounts.User
  alias Wik.Repo

  require Ash.Query

  def find_or_create_identity(%{"sub" => google_user_id, "email" => email} = google_user) do
    provider_user_id = to_string(google_user_id)

    with {:ok, normalized_email} <- validate_email(email),
         {:ok, identity} <- load_external_identity(:google, provider_user_id) do
      case identity do
        nil -> find_or_create_user_and_identity(provider_user_id, normalized_email, google_user)
        identity -> update_external_identity(identity, normalized_email, google_user)
      end
    end
  end

  def find_or_create_identity(_google_user), do: {:error, :email_required}

  def apply_email_access(%User{} = user) do
    with {:ok, identity} <- load_google_identity(user),
         {:ok, email_rules} <- Access.list_active_google_email_rules(identity.email),
         :ok <- authorize_email_rules(email_rules) do
      email_rules
      |> Enum.reduce_while({:ok, []}, fn email_rule, {:ok, grants} ->
        case apply_email_rule(email_rule, identity, user) do
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

  def upsert_email_rule(%{id: space_id} = space, attrs, %User{} = actor) do
    with {:ok, source} <- get_or_create_space_source(space),
         {:ok, email} <- fetch_normalized_email(attrs),
         {:ok, membership_type} <- fetch_membership_type(attrs) do
      Access.upsert_google_email_rule(
        %{
          email: email,
          granted_by_user_id: actor.id,
          membership_type: membership_type,
          revoked_at: nil,
          revoked_by_user_id: nil,
          source_id: source.id,
          space_id: space_id
        },
        actor: actor
      )
    end
  end

  def revoke_email_rule(email_rule_id, %User{} = actor) when is_binary(email_rule_id) do
    with {:ok, email_rule} <- Ash.get(EmailRule, email_rule_id, authorize?: false),
         {:ok, email_rule} <-
           Ash.update(
             email_rule,
             %{revoked_at: DateTime.utc_now(), revoked_by_user_id: actor.id},
             action: :revoke,
             actor: actor,
             domain: Access
           ),
         :ok <- deactivate_grants(email_rule) do
      {:ok, email_rule}
    end
  end

  def get_or_create_space_source(%{id: space_id}) do
    Access.upsert_source(
      %{
        metadata: %{"kind" => "google_account"},
        provider: :google,
        provider_source_id: google_source_provider_source_id(space_id),
        space_id: space_id,
        status: :active,
        title: "Google account"
      },
      authorize?: false
    )
  end

  def normalize_email(email) when is_binary(email) do
    email
    |> String.trim()
    |> String.downcase()
  end

  def normalize_email(_email), do: ""

  def google_source_provider_source_id(space_id), do: "google:space:#{space_id}"

  defp find_or_create_user_and_identity(provider_user_id, email, google_user) do
    case load_user_by_email(email) do
      {:ok, nil} -> create_user_and_identity(provider_user_id, email, google_user)
      {:ok, user} -> create_identity(provider_user_id, email, google_user, user)
      {:error, error} -> {:error, error}
    end
  end

  defp create_user_and_identity(provider_user_id, email, google_user) do
    case Repo.transaction(fn ->
           with {:ok, user, user_notifications} <-
                  Ash.create(User, %{email: email},
                    action: :create_from_external_identity,
                    authorize?: false,
                    return_notifications?: true
                  ),
                {:ok, identity, identity_notifications} <-
                  Ash.create(
                    ExternalIdentity,
                    google_identity_attrs(provider_user_id, email, google_user, user.id),
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

  defp create_identity(provider_user_id, email, google_user, user) do
    ExternalIdentity
    |> Ash.Changeset.for_create(
      :create,
      google_identity_attrs(provider_user_id, email, google_user, user.id),
      authorize?: false
    )
    |> Ash.create()
    |> case do
      {:ok, identity} -> Ash.load(identity, [:user], authorize?: false)
      {:error, error} -> {:error, error}
    end
  end

  defp update_external_identity(identity, email, google_user) do
    identity
    |> Ash.update(google_identity_attrs(email, google_user),
      action: :update,
      authorize?: false
    )
    |> case do
      {:ok, identity} -> Ash.load(identity, [:user], authorize?: false)
      {:error, error} -> {:error, error}
    end
  end

  defp load_user_by_email(email) do
    User
    |> Query.filter(email == ^email)
    |> Ash.read_one(authorize?: false, domain: Wik.Accounts)
  end

  defp load_external_identity(provider, provider_user_id) do
    ExternalIdentity
    |> Query.filter(provider == ^provider and provider_user_id == ^provider_user_id)
    |> Ash.read_one(authorize?: false, load: [:user])
  end

  defp load_google_identity(%{id: user_id}) do
    ExternalIdentity
    |> Query.filter(provider == :google and user_id == ^user_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :google_identity_not_found}
      result -> result
    end
  end

  defp authorize_email_rules([]), do: {:error, :google_email_rule_not_found}
  defp authorize_email_rules(_email_rules), do: :ok

  defp apply_email_rule(email_rule, identity, user) do
    with :ok <- ensure_membership(email_rule, user),
         {:ok, grant} <- upsert_grant(email_rule, identity, user) do
      {:ok, grant}
    end
  end

  defp ensure_membership(%{space_id: space_id, membership_type: membership_type}, %{id: user_id}) do
    Membership
    |> Query.filter(space_id == ^space_id and user_id == ^user_id)
    |> Ash.read_one(authorize?: false, domain: Wik.Accounts)
    |> case do
      {:ok, nil} -> create_membership(space_id, user_id, membership_type)
      {:ok, %{type: :owner}} -> :ok
      {:ok, %{type: ^membership_type}} -> :ok
      {:ok, membership} -> update_membership_type(membership, membership_type)
      {:error, error} -> {:error, error}
    end
  end

  defp create_membership(space_id, user_id, membership_type) do
    case Ash.create(
           Membership,
           %{space_id: space_id, type: membership_type, user_id: user_id},
           authorize?: false,
           domain: Wik.Accounts
         ) do
      {:ok, _membership} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp update_membership_type(membership, membership_type) do
    case Ash.update(membership, %{type: membership_type},
           action: :set_type,
           authorize?: false,
           domain: Wik.Accounts
         ) do
      {:ok, _membership} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp upsert_grant(email_rule, identity, user) do
    Access.upsert_grant(
      %{
        external_identity_id: identity.id,
        granted_by_user_id: email_rule.granted_by_user_id,
        last_verified_at: DateTime.utc_now(),
        source_id: email_rule.source_id,
        status: :active,
        user_id: user.id
      },
      authorize?: false
    )
  end

  defp deactivate_grants(%{email: email, source_id: source_id}) do
    Grant
    |> Query.filter(
      source_id == ^source_id and external_identity.email == ^email and status == :active
    )
    |> Ash.read(authorize?: false, domain: Access)
    |> case do
      {:ok, grants} ->
        Enum.reduce_while(grants, :ok, fn grant, :ok ->
          case Ash.update(grant, %{status: :inactive},
                 action: :update,
                 authorize?: false,
                 domain: Access
               ) do
            {:ok, _grant} -> {:cont, :ok}
            {:error, error} -> {:halt, {:error, error}}
          end
        end)

      {:error, error} ->
        {:error, error}
    end
  end

  defp fetch_normalized_email(%{"email" => email}), do: validate_email(email)
  defp fetch_normalized_email(%{email: email}), do: validate_email(email)
  defp fetch_normalized_email(_attrs), do: {:error, :email_required}

  defp validate_email(email) do
    case normalize_email(email) do
      "" -> {:error, :email_required}
      email -> {:ok, email}
    end
  end

  defp fetch_membership_type(%{"membership_type" => "admin"}), do: {:ok, :admin}
  defp fetch_membership_type(%{"membership_type" => "member"}), do: {:ok, :member}
  defp fetch_membership_type(%{"membership_type" => :admin}), do: {:ok, :admin}
  defp fetch_membership_type(%{"membership_type" => :member}), do: {:ok, :member}
  defp fetch_membership_type(%{membership_type: :admin}), do: {:ok, :admin}
  defp fetch_membership_type(%{membership_type: :member}), do: {:ok, :member}
  defp fetch_membership_type(_attrs), do: {:ok, :member}

  defp google_identity_attrs(provider_user_id, email, google_user, user_id) do
    google_identity_attrs(email, google_user)
    |> Map.put(:provider, :google)
    |> Map.put(:provider_user_id, provider_user_id)
    |> Map.put(:user_id, user_id)
  end

  defp google_identity_attrs(email, google_user) do
    %{
      avatar_url: google_user["picture"],
      display_name: google_user["name"],
      email: email,
      metadata: google_identity_metadata(google_user),
      username: nil
    }
  end

  defp google_identity_metadata(google_user) do
    %{
      "email_verified" => google_user["email_verified"],
      "family_name" => google_user["family_name"],
      "given_name" => google_user["given_name"],
      "locale" => google_user["locale"],
      "name" => google_user["name"],
      "picture" => google_user["picture"],
      "provider" => "google",
      "sub" => google_user["sub"]
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
