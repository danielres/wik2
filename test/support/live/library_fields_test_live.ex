defmodule WikWeb.LibraryFieldsTestLive do
  use WikWeb, :live_view

  alias WikWeb.Components.RichTextInput

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl space-y-8 p-8">
      <.form for={to_form(%{"notes" => "Portable notes"}, as: :entry)} id="library-fields-form">
        <RichTextInput.field
          id="library-notes"
          label="Notes"
          name="entry[notes]"
          value="Portable notes"
        />
      </.form>

      <textarea id="portable-schema" phx-no-curly-interpolation>{"format":"wik-library-schema","version":1}</textarea>
      <button
        data-copy-source-id="portable-schema"
        data-testid="copy-schema"
        id="copy-schema"
        phx-hook="CopyToClipboard"
        type="button"
      >
        Copy schema
      </button>
    </div>
    """
  end
end
