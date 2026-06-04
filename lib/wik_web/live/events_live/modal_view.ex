defmodule WikWeb.EventsLive.ModalView do
  alias WikWeb.EventsLive.SubscriptionState

  def build(assigns) do
    case assigns.modal do
      {:event_form, form, show_end_date?, interest_form} ->
        %{
          kind: :event_form,
          title: if(form.source.type == :create, do: "Create event", else: "Edit event"),
          dialog_testid: "event-modal-dialog",
          close_testid: "event-modal-close",
          form: form,
          interest_form: interest_form,
          show_end_date?: show_end_date?
        }

      {:internal_event, publication} ->
        %{
          kind: :internal_event,
          title: nil,
          dialog_testid: "event-modal-dialog",
          close_testid: "event-modal-close",
          publication: publication
        }

      {:external_event, item} ->
        %{
          kind: :external_event,
          title: nil,
          dialog_testid: "event-modal-dialog",
          close_testid: "event-modal-close",
          item: item
        }

      {:event_interest, source_type, source, form} ->
        %{
          kind: :event_interest,
          title: "Your interest",
          dialog_testid: "event-interest-dialog",
          close_testid: "event-interest-cancel",
          form: form,
          source: source,
          source_type: source_type
        }

      {:new_subscription, form, error} ->
        %{
          kind: :new_subscription,
          title: "Subscribe to calendar",
          dialog_testid: "events-subscription-modal-dialog",
          close_testid: "events-subscription-modal-close",
          form: form,
          error: error
        }

      {:subscription, subscription, name_form} ->
        %{
          kind: :subscription,
          title: SubscriptionState.title(assigns.subscriptions, subscription),
          dialog_testid: "events-subscription-detail-dialog",
          close_testid: "events-subscription-detail-close",
          subscription: subscription,
          name_form: name_form,
          metadata: SubscriptionState.metadata(assigns.subscriptions, subscription)
        }

      nil ->
        nil
    end
  end
end
