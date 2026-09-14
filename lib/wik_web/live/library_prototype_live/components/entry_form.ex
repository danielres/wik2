defmodule WikWeb.LibraryPrototypeLive.Components.EntryForm do
  use WikWeb, :html

  alias WikWeb.Components.LocationPicker
  alias WikWeb.Components.RichTextInput

  attr :cancel_event, :string, default: "modal:close"
  attr :change_event, :string, default: "entry:change"
  attr :form, :map, required: true
  attr :id, :string, default: "entry-form"
  attr :metadata_error, :string, default: nil
  attr :metadata_loading?, :boolean, default: false
  attr :mode, :atom, required: true
  attr :submit_event, :string, default: nil
  attr :submit_label, :string, default: nil
  attr :testid, :string, default: "entry-form"
  attr :type, :map, required: true

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:resolved_submit_event, fn ->
        assigns.submit_event || if(assigns.mode == :new, do: "entry:create", else: "entry:update")
      end)
      |> assign_new(:resolved_submit_label, fn ->
        assigns.submit_label || if(assigns.mode == :new, do: "Add entry", else: "Save entry")
      end)

    ~H"""
    <.form
      class="space-y-5"
      data-testid={@testid}
      for={@form}
      id={@id}
      phx-change={@change_event}
      phx-submit={@resolved_submit_event}
    >
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
          :if={field.type == :media && (@metadata_loading? || @metadata_error)}
          aria-live="polite"
          class="mt-1 flex min-h-4 items-center gap-1.5 text-xs text-base-content/50"
          data-testid="entry-media-status"
        >
          <span :if={@metadata_loading?} class="loading loading-spinner loading-xs"></span>
          <span :if={@metadata_error} class="text-error/75">{@metadata_error}</span>
        </div>
      </div>

      <div class="flex justify-between gap-2 ">
        <button class="btn btn-ghost" phx-click={@cancel_event} type="button">Cancel</button>
        <button class="btn btn-accent" data-testid="entry-submit" type="submit">
          {@resolved_submit_label}
        </button>
      </div>
    </.form>
    """
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
