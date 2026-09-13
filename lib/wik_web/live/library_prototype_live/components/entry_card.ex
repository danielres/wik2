defmodule WikWeb.LibraryPrototypeLive.Components.EntryCard do
  use WikWeb, :html

  alias WikWeb.LibraryPrototypeLive.EntryPresentation
  alias WikWeb.LibraryPrototypeLive.FieldPresentation
  alias WikWeb.LibraryPrototypeLive.Schema

  attr :type, :map, required: true
  attr :entry, :map, required: true
  attr :manageable?, :boolean, required: true
  attr :owned?, :boolean, required: true
  attr :topic_summaries, :list, required: true

  def render(assigns) do
    assigns =
      assigns
      |> assign(:playlist_label, EntryPresentation.playlist_label(assigns.type, assigns.entry))
      |> assign(:preview, EntryPresentation.preview(assigns.type, assigns.entry))
      |> assign(
        :preview_field?,
        Enum.any?(assigns.type.fields, &(&1.type in [:location, :media]))
      )
      |> assign(:summary_fields, summary_fields(assigns.type, assigns.entry))
      |> assign(:title, EntryPresentation.title(assigns.type, assigns.entry))

    ~H"""
    <div class={[
      "grid min-w-0 grid-rows-subgrid text-left row-span-2 gap-4",
      "relative"
    ]}>
      <div class={[
        "px-2 py-1",
        "text-[11px] uppercase tracking-wider text-base-content/28 whitespace-nowrap",
        "font-semibold",
        "absolute right-0 top-0"
      ]}>
        {@type.name |> String.replace("External", "Ex.")}
      </div>
      <div class="flex gap-2 px-4 pt-4">
        <h3 class={[
          "leading-tight text-balance Xself-end line-clamp-2 font-bold",
          "text-base-content/95 group-hover:text-base-content transition"
        ]}>
          {@title}
        </h3>
      </div>

      <div class="space-y-2 px-4">
        <dl class="space-y-0.5 text-xs text-base-content/55">
          <div :for={field <- @summary_fields} class="flex min-w-0 gap-1">
            <dt class="flex shrink-0 items-center font-semibold" title={field.label}>
              <%= if icon = FieldPresentation.entry_icon(field) do %>
                <.icon name={icon} class="size-3.5" />
                <span class="sr-only">{field.label}:</span>
              <% else %>
                {field.label}:
              <% end %>
            </dt>
            <dd class="w-0 min-w-0 flex-1 truncate">
              {display_value(Schema.field_value(@entry, field), field)}
            </dd>
          </div>
        </dl>
      </div>
    </div>

    <div class="flex items-center gap-2 self-center">
      <span :if={@owned?} class="badge badge-sm badge-outline">Yours</span>
    </div>

    <div class="stacked content-end">
      <div
        :if={@preview_field?}
        class={[
          "p-2",
          "opacity-70 group-hover:opacity-90",
          "blur-[0.6px] group-hover:blur-none",
          "transition"
        ]}
        data-testid={"entry-preview-#{@entry.id}"}
      >
        <div class={[
          "aspect-video w-full",
          "items-center justify-center",
          "overflow-hidden",
          "rounded"
        ]}>
          <iframe
            :if={@preview && !@preview.thumbnail_url && @preview.embed_url}
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen
            aria-hidden="true"
            class="pointer-events-none h-full w-full border-0"
            loading="lazy"
            referrerpolicy="strict-origin-when-cross-origin"
            src={@preview.embed_url}
            tabindex="-1"
            title={@title}
          >
          </iframe>
          <img
            :if={@preview && @preview.thumbnail_url}
            alt=""
            class="h-full w-full object-cover opacity-80 transition"
            loading="lazy"
            src={@preview.thumbnail_url}
          />
          <.icon
            :if={@preview && !@preview.thumbnail_url && !@preview.embed_url}
            name={preview_fallback_icon(@preview.provider)}
            class="size-8 opacity-25"
          />
          <.icon :if={!@preview} name="hero-document-text" class="size-8 opacity-20" />
        </div>
      </div>

      <span
        :if={@playlist_label}
        class={[
          "relative z-[1] m-4 self-start justify-self-end",
          "badge badge-sm gap-1 bg-base-300/90"
        ]}
        data-testid={"entry-playlist-indicator-#{@entry.id}"}
      >
        {@playlist_label}
      </span>

      <div class={[
        "relative self-end p-2 m-2",
        @topic_summaries != [] && @preview_field? && "bg-base-100/60 backdrop-blur rounded-b",
        @topic_summaries != [] && @preview_field? &&
          "group-hover:translate-y-[100%] group-hover:opacity-0 transition"
      ]}>
        <div :if={@topic_summaries != []} class="flex flex-wrap gap-1.5">
          <span
            :for={summary <- Enum.take(@topic_summaries, 6)}
            class="badge badge-sm gap-1 bg-base-300"
            data-testid={"entry-topic-#{@entry.id}-#{summary.tag.id}"}
          >
            <.icon :if={summary.automatic?} name="hero-sparkles-micro" class="size-3" />
            {summary.tag.name}
          </span>
          <span :if={length(@topic_summaries) > 6} class="badge badge-sm ">
            +{length(@topic_summaries) - 6}
          </span>
        </div>
      </div>
    </div>
    """
  end

  defp preview_fallback_icon(:google_maps), do: "hero-map-pin"
  defp preview_fallback_icon(:soundcloud), do: "hero-musical-note"
  defp preview_fallback_icon(_provider), do: "hero-link"

  defp summary_fields(type, entry) do
    type.fields
    |> Enum.filter(fn field ->
      field.type not in [:title, :media, :rich_text] and
        not Schema.blank_value?(Schema.field_value(entry, field))
    end)
    |> Enum.take(3)
  end

  defp display_value(value, %{type: :boolean}), do: if(value, do: "Yes", else: "No")
  defp display_value(value, _field), do: to_string(value)
end
