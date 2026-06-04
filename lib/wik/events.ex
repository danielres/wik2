defmodule Wik.Events do
  use Ash.Domain,
    otp_app: :wik,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  import Ecto.Query, only: [from: 2]
  require Ash.Expr
  require Ash.Query

  alias Ash.Query
  alias Utils.Values
  alias Wik.Accounts
  alias Wik.Accounts.Space
  alias Wik.Events.Event
  alias Wik.Events.EventParticipation
  alias Wik.Events.ExternalEvent
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.EventPublication
  alias Wik.Events.EventPublication.Checks
  alias Wik.Events.Feeds
  alias Wik.Repo

  admin do
    show? true
  end

  resources do
    resource Event
    resource EventParticipation
    resource EventPublication
    resource ExternalEvent
    resource ExternalCalendarSubscription
  end

  def record_interest(%EventPublication{} = publication, attrs, opts \\ []) do
    scope = Keyword.fetch!(opts, :scope)

    with {:ok, membership} when not is_nil(membership) <-
           Accounts.get_membership(publication.target_space_id, scope.actor.id),
         {:ok, participation_attrs} <- participation_attrs(attrs) do
      upsert_participation(publication, membership, participation_attrs, opts)
    else
      {:ok, nil} -> {:error, :membership_not_found}
      {:error, error} -> {:error, error}
    end
  end

  def record_event_interest(%Event{} = event, attrs, opts \\ []) do
    scope = Keyword.fetch!(opts, :scope)

    with {:ok, publication} when not is_nil(publication) <- origin_publication(event, scope) do
      record_interest(publication, attrs, opts)
    else
      {:ok, nil} -> {:error, :publication_not_found}
      {:error, error} -> {:error, error}
    end
  end

  def record_external_interest(%ExternalEvent{} = external_event, attrs, opts \\ []) do
    scope = Keyword.fetch!(opts, :scope)

    with {:ok, publication} <- publication_for_external_event(external_event, scope),
         {:ok, participation} <- record_interest(publication, attrs, opts) do
      {:ok, %{publication: publication, participation: participation}}
    end
  end

  def update_converted_event_layer(%Event{} = event, attrs, opts \\ []) do
    attrs = %{
      description:
        Values.blank_to_nil(Map.get(attrs, :description) || Map.get(attrs, "description")),
      title: Values.blank_to_nil(Map.get(attrs, :title) || Map.get(attrs, "title"))
    }

    Ash.update(event, attrs, Keyword.put(opts, :action, :update_converted_layer))
  end

  def event_participations_query(publication_ids) when is_list(publication_ids) do
    EventParticipation
    |> Query.filter(publication_id in ^publication_ids)
    |> Query.load(membership: [:avatar_url, :user])
    |> Query.sort([:inserted_at])
  end

  def external_calendar_subscriptions_query do
    ExternalCalendarSubscription
    |> Query.sort(inserted_at: :asc)
    |> Query.load(:space)
  end

  def external_events_query do
    ExternalEvent
    |> Query.sort(starts_at: :asc)
  end

  defp publication_for_external_event(%ExternalEvent{} = external_event, scope) do
    with {:ok, event} <- event_for_external_event(external_event, scope) do
      origin_publication(event, scope)
    end
  end

  defp event_for_external_event(%ExternalEvent{} = external_event, scope) do
    case get_event_for_external_event(external_event, scope) do
      {:ok, %Event{} = event} ->
        {:ok, event}

      {:ok, nil} ->
        Ash.create(
          Event,
          %{description: nil, source_external_event_id: external_event.id, title: nil},
          action: :create_from_external,
          scope: scope
        )

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_event_for_external_event(%ExternalEvent{} = external_event, scope) do
    Event
    |> Query.filter(source_external_event_id == ^external_event.id)
    |> Ash.read_one(scope: scope)
  end

  defp origin_publication(%Event{} = event, scope) do
    EventPublication
    |> Query.filter(event_id == ^event.id and target_space_id == ^scope.tenant.id)
    |> Query.load([
      :space,
      :published_by,
      event: [:author, :space, source_external_event: [:subscription]]
    ])
    |> Ash.read_one(scope: scope)
  end

  defp upsert_participation(publication, membership, attrs, opts) do
    identity_attrs = %{
      membership_id: membership.id,
      publication_id: publication.id
    }

    case get_participation_by_identity(identity_attrs, Keyword.fetch!(opts, :scope)) do
      {:ok, nil} ->
        Ash.create(
          EventParticipation,
          Map.merge(identity_attrs, attrs),
          Keyword.put(opts, :action, :create)
        )

      {:ok, %EventParticipation{} = participation} ->
        Ash.update(
          participation,
          attrs,
          Keyword.put(opts, :action, :update_details)
        )

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_participation_by_identity(attrs, scope) do
    EventParticipation
    |> Query.filter(
      publication_id == ^attrs.publication_id and membership_id == ^attrs.membership_id
    )
    |> Ash.read_one(scope: scope, authorize?: false)
  end

  defp participation_attrs(attrs) do
    interest = Map.get(attrs, :interest) || Map.get(attrs, "interest")
    extra_info = Map.get(attrs, :extra_info) || Map.get(attrs, "extra_info")

    with {:ok, interest} <- parse_interest(interest) do
      {:ok, %{extra_info: Values.blank_to_nil(extra_info), interest: interest}}
    end
  end

  defp parse_interest(value) when is_integer(value) and value in 0..10, do: {:ok, value}

  defp parse_interest(value) when is_binary(value) do
    case Integer.parse(value) do
      {interest, ""} when interest in 0..10 -> {:ok, interest}
      _ -> {:error, :invalid_interest}
    end
  end

  defp parse_interest(_value), do: {:error, :invalid_interest}

  # relay ======================================================================

  def relay_to_space(%Event{} = event, target_space, opts) do
    scope = Keyword.fetch!(opts, :scope)

    EventPublication.relay_to_space(
      %{event_id: event.id, relay_note: Keyword.get(opts, :relay_note)},
      scope: %{scope | tenant: target_space}
    )
  end

  def can_relay_event_to_any_space?(%Event{} = event, scope) do
    case list_relay_target_spaces(event, scope) do
      {:ok, relay_target_spaces} -> {:ok, relay_target_spaces != []}
      {:error, error} -> {:error, error}
    end
  end

  # feeds ======================================================================

  defdelegate get_space_feed(user, space_id), to: Feeds
  defdelegate list_aggregate_feed_events(user), to: Feeds

  def list_relay_target_spaces(%Event{} = event, scope) do
    published_space_ids = published_space_ids(event)

    with {:ok, spaces} <-
           Space
           |> Ash.Query.sort(name: :asc)
           |> Ash.read(scope: scope),
         {:ok, spaces} <-
           filter_relay_target_spaces(spaces, event, published_space_ids, scope.actor.id) do
      {:ok, spaces}
    end
  end

  defp published_space_ids(%Event{id: event_id}) do
    from(ep in "event_publications",
      where: ep.event_id == type(^event_id, :binary_id),
      select: ep.target_space_id
    )
    |> Repo.all()
    |> Enum.map(&Ecto.UUID.load!/1)
    |> MapSet.new()
  end

  defp filter_relay_target_spaces(spaces, event, published_space_ids, actor_id) do
    spaces
    |> Enum.reject(&(MapSet.member?(published_space_ids, &1.id) or &1.id == event.space_id))
    |> Enum.reduce_while({:ok, []}, fn space, {:ok, acc} ->
      case Checks.ActorCanRelayEvent.relay_allowed_by_event_policy?(actor_id, event, space.id) do
        {:ok, true} ->
          {:cont, {:ok, [space | acc]}}

        {:ok, false} ->
          {:cont, {:ok, acc}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, spaces} ->
        {:ok, Enum.reverse(spaces)}

      {:error, error} ->
        {:error, error}
    end
  end
end
