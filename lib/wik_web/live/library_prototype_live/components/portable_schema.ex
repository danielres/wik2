defmodule WikWeb.LibraryPrototypeLive.Components.PortableSchema do
  use WikWeb, :html

  attr :export_json, :string, required: true

  def render(assigns) do
    ~H"""
    <section
      class="rounded-box border border-base-content/10 bg-base-200/40 p-5"
      data-testid="portable-schema"
    >
      <div class="flex items-center justify-between gap-4">
        <h2 class="font-bold">Portable schema</h2>
        <button
          class="btn btn-sm"
          data-copy-source-id="library-schema-json"
          data-testid="schema-copy"
          id="library-schema-copy"
          phx-hook="CopyToClipboard"
          type="button"
        >
          <.icon name="hero-document-duplicate-micro" class="opacity-50" /> Copy JSON
        </button>
      </div>
      <textarea
        id="library-schema-json"
        class="textarea mt-2 h-40 w-full font-mono text-xs leading-relaxed text-base-content/50"
        readonly
      >{@export_json}</textarea>
    </section>
    """
  end
end
