defmodule WikWeb.LibraryLive.Components.EntryForm do
  use WikWeb, :live_component

  alias WikWeb.Components.LocationPicker
  alias WikWeb.Components.RichTextInput
  alias WikWeb.Components.UI
  alias WikWeb.LibraryLive.EntryFormMedia
  alias WikWeb.LibraryLive.ExternalMedia
  alias WikWeb.LibraryLive.State

  @impl true
  def update(assigns, socket) do
    form_key = {assigns.mode, assigns.type.id, assigns.entry && assigns.entry.id}
    socket = assign(socket, assigns)

    socket =
      if socket.assigns[:form_key] == form_key do
        socket
      else
        params = if assigns.entry, do: assigns.entry.values, else: %{}
        metadata = if assigns.entry, do: assigns.entry.external_media_metadata, else: nil

        assign(socket,
          error: nil,
          form: to_form(params, as: :entry),
          form_key: form_key,
          media: EntryFormMedia.reset(metadata)
        )
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("change", %{"entry" => incoming_params} = event, socket) do
    target = get_in(event, ["_target", Access.at(1)])

    case EntryFormMedia.change(
           socket.assigns.media,
           socket.assigns.form.params,
           incoming_params,
           target,
           socket.assigns.type
         ) do
      {:ok, params, media} ->
        {:noreply, assign_form(socket, params, media)}

      {:resolve, params, url, media} ->
        {:noreply, resolve_external_media(socket, params, url, media)}
    end
  end

  def handle_event("save", %{"entry" => params}, %{assigns: %{mode: :new}} = socket) do
    case State.create_entry(
           socket.assigns.library_state,
           socket.assigns.type,
           socket.assigns.actor_id,
           socket.assigns.admin?,
           params,
           socket.assigns.media.external_metadata
         ) do
      {:ok, state, entry} ->
        send(self(), {__MODULE__, {:created, state, entry}})
        {:noreply, assign(socket, :library_state, state)}

      {:error, errors} when is_list(errors) ->
        {:noreply, assign_error(socket, params, Enum.join(errors, " · "))}

      {:error, _reason} ->
        {:noreply, assign_error(socket, params, "You cannot add entries to that Library type.")}
    end
  end

  def handle_event("save", %{"entry" => params}, %{assigns: %{mode: :edit}} = socket) do
    case State.update_entry(
           socket.assigns.library_state,
           socket.assigns.type,
           socket.assigns.entry.id,
           socket.assigns.actor_id,
           socket.assigns.admin?,
           params,
           socket.assigns.media.external_metadata
         ) do
      {:ok, state, entry} ->
        send(self(), {__MODULE__, {:updated, state, entry}})
        {:noreply, assign(socket, :library_state, state)}

      {:error, errors} when is_list(errors) ->
        {:noreply, assign_error(socket, params, Enum.join(errors, " · "))}

      {:error, reason} when is_binary(reason) ->
        {:noreply, assign_error(socket, params, reason)}

      {:error, _reason} ->
        {:noreply, assign_error(socket, params, "You cannot edit that Library entry.")}
    end
  end

  def handle_event("cancel", _params, socket) do
    send(self(), {__MODULE__, :cancelled})
    {:noreply, socket}
  end

  @impl true
  def handle_async({:external_media, request_id}, {:ok, result}, socket) do
    if EntryFormMedia.matching_request?(
         socket.assigns.media,
         request_id,
         socket.assigns.form.params
       ) do
      {params, media} =
        EntryFormMedia.apply_result(socket.assigns.media, socket.assigns.form.params, result)

      {:noreply, assign_form(socket, params, media)}
    else
      {:noreply, socket}
    end
  end

  def handle_async({:external_media, request_id}, {:exit, _reason}, socket) do
    if EntryFormMedia.request_id(socket.assigns.media) == request_id do
      {:noreply, assign(socket, :media, EntryFormMedia.fail(socket.assigns.media))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"#{@form_id}-component"}>
      <.form
        class="space-y-5"
        data-testid={@testid}
        for={@form}
        id={@form_id}
        phx-change="change"
        phx-submit="save"
        phx-target={@myself}
      >
        <p :if={@error} class="text-sm text-error" data-testid="entry-form-error">
          {@error}
        </p>

        <div :if={@mode == :edit} role="alert" class="alert text-base-content/80">
          <.icon name="hero-exclamation-triangle-micro" class="opacity-60 size-5" />
          <span>Editing this entry updates it everywhere it appears.</span>
        </div>

        <div :for={field <- @type.fields}>
          <RichTextInput.field
            :if={field.type == :rich_text}
            id={"entry-#{field.key}"}
            label={field.label}
            name={Phoenix.HTML.Form.input_name(@form, field.key)}
            required={field.required?}
            value={Phoenix.HTML.Form.input_value(@form, field.key) || ""}
          />
          <LocationPicker.field
            :if={field.type == :location}
            field={@form[field.key]}
            id={"entry-#{field.key}"}
            label={field.label}
            testid={"entry-field-#{field.key}"}
          />
          <.input
            :if={field.type not in [:rich_text, :location]}
            data-testid={"entry-field-#{field.key}"}
            field={@form[field.key]}
            label={field.label}
            options={if(field.type == :select, do: Enum.map(field.options, &{&1, &1}), else: [])}
            phx-debounce={if(field.type == :media, do: "500", else: nil)}
            prompt={
              if(field.type == :select and not field.required?, do: "Choose an option", else: nil)
            }
            required={field.required?}
            type={input_type(field.type)}
          />
          <div
            :if={field.type == :media && (@media.loading? || @media.error)}
            aria-live="polite"
            class="mt-1 flex min-h-4 items-center gap-1.5 text-xs text-base-content/50"
            data-testid="entry-media-status"
          >
            <span :if={@media.loading?} class="loading loading-spinner loading-xs"></span>
            <span :if={@media.error} class="text-error/75">{@media.error}</span>
          </div>
        </div>

        <div class="flex justify-between gap-2">
          <.button_entry_delete :if={@mode == :edit} entry={@entry} />
          <button
            :if={@mode == :new}
            class="btn btn-ghost"
            phx-click="cancel"
            phx-target={@myself}
            type="button"
          >
            Cancel
          </button>
          <button class="btn btn-accent" data-testid="entry-submit" type="submit">
            {@submit_label}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  attr :entry, :map, required: true

  defp button_entry_delete(assigns) do
    ~H"""
    <UI.action_button
      data-tip="Delete"
      icon="hero-trash-micro"
      data-confirm="Delete this entry?"
      data-testid={"entry-delete-#{@entry.id}"}
      phx-click="entry:delete"
      phx-value-entry_id={@entry.id}
      variant="error"
    />
    """
  end

  defp resolve_external_media(socket, params, url, media) do
    request_id = System.unique_integer([:monotonic, :positive])
    media = EntryFormMedia.begin_resolution(media, url, request_id)

    socket
    |> assign_form(params, media)
    |> start_async({:external_media, request_id}, fn -> ExternalMedia.resolve(url) end)
  end

  defp assign_form(socket, params, media) do
    assign(socket,
      error: nil,
      form: to_form(params, as: :entry),
      media: media
    )
  end

  defp assign_error(socket, params, error) do
    assign(socket, error: error, form: to_form(params, as: :entry))
  end

  defp input_type(:boolean), do: "checkbox"
  defp input_type(:date), do: "date"
  defp input_type(:email), do: "email"
  defp input_type(:media), do: "url"
  defp input_type(:number), do: "number"
  defp input_type(:phone), do: "tel"
  defp input_type(:select), do: "select"
  defp input_type(:url), do: "url"
  defp input_type(_type), do: "text"
end
