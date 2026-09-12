defmodule WikWeb.LibraryPrototypeLive.Components.TypeList do
  use WikWeb, :html

  attr :space_slug, :string, required: true
  attr :types, :list, required: true

  def render(assigns) do
    ~H"""
    <div class="space-y-4" data-testid="types-page">
      <div class="flex items-center justify-between gap-3">
        <h1 class="text-2xl flex items-center gap-2 text-base-content/80">
          <.icon name="hero-circle-stack-micro" /> Types
        </h1>

        <.link
          class="btn btn-sm btn-primary"
          data-testid="type-create-open"
          patch={~p"/#{@space_slug}/libraries/types/new"}
        >
          <.icon name="hero-plus-micro" /> Add type
        </.link>
      </div>
      <div class="divide-y divide-base-content/10 rounded-box bg-base-200/40 px-4">
        <.link
          :for={type <- @types}
          class="flex items-center justify-between gap-4 py-4"
          data-testid={"type-manage-#{type.slug}"}
          patch={~p"/#{@space_slug}/libraries/types/#{type.slug}/settings"}
        >
          <span class="font-semibold">{type.name}</span>
          <span class="flex items-center gap-2 text-sm text-base-content/45">
            {type.entry_count} <.icon name="hero-chevron-right-micro" />
          </span>
        </.link>
      </div>
    </div>
    """
  end
end
