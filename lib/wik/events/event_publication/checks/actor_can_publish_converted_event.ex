defmodule Wik.Events.EventPublication.Checks.ActorCanPublishConvertedEvent do
  use Ash.Policy.SimpleCheck

  alias Wik.Accounts
  alias Wik.Events.Event

  require Ash.Query

  @impl true
  def describe(_opts), do: "actor can publish the converted event they just created"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, %{subject: subject} = context, _opts) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)
    space_id = Accounts.tenant_to_space_id(tenant)
    event_id = Ash.Subject.get_argument_or_attribute(subject, :event_id)

    Event
    |> Ash.Query.filter(
      id == ^event_id and
        author_id == ^actor.id and
        space_id == ^space_id and
        not is_nil(source_external_event_id)
    )
    |> Ash.exists(authorize?: false, domain: Wik.Events)
  end
end
