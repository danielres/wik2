defmodule WikWeb.LibraryLive.Components.TypeList do
  use WikWeb, :html

  alias WikWeb.Components.UI

  attr :space_slug, :string, required: true
  attr :types, :list, required: true

  def render(assigns) do
    ~H"""
    <div class="space-y-4 max-w-[80ch] mx-auto" data-testid="types-page">
      <div class="flex items-center justify-between gap-3">
        <h1 class="text-2xl flex items-center gap-2 text-base-content/80">
          <.icon name="hero-circle-stack-micro" /> Types
        </h1>

        <UI.action_button
          data-tip="Add type"
          icon="hero-plus-micro"
          data-testid="type-create-open"
          patch={~p"/#{@space_slug}/libraries/types/new"}
        />
      </div>

      <div class="divide-y divide-base-content/10 rounded-box bg-base-200/40 px-4">
        <.link
          :for={type <- @types}
          class="flex items-center justify-between gap-4 py-4"
          data-testid={"type-manage-#{type.slug}"}
          patch={~p"/#{@space_slug}/libraries/types/#{type.slug}/settings"}
        >
          <span class="font-semibold small-caps">{type.name}</span>
          <span class="flex items-center gap-2 text-sm text-base-content/45">
            {type.entry_count} <.icon name="hero-chevron-right-micro" />
          </span>
        </.link>
      </div>
    </div>
    """
  end
end
