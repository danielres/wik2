defmodule WikWeb.LibraryPrototypeLive.Components.EntryDetail do
  use WikWeb, :html

  alias WikWeb.LibraryPrototypeLive.EntryPresentation
  alias WikWeb.LibraryPrototypeLive.Schema

  attr :type, :map, required: true
  attr :entry, :map, required: true
  attr :manageable?, :boolean, required: true
  attr :topic_form, :map, default: nil
  attr :topic_options, :list, required: true
  attr :topic_summaries, :list, required: true

  def render(assigns) do
    assigns =
      assigns
      |> assign(:map_embed_url, EntryPresentation.map_embed_url(assigns.type, assigns.entry))
      |> assign(:media, EntryPresentation.media(assigns.type, assigns.entry))
      |> assign(:playlist, EntryPresentation.playlist(assigns.type, assigns.entry))
      |> assign(:title, EntryPresentation.title(assigns.type, assigns.entry))

    ~H"""
    <div class="" data-testid={"library-entry-detail-#{@entry.id}"}>
      <div :if={@media && @media.embed_url} class="overflow-hidden rounded-box bg-base-300">
        <iframe
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
          allowfullscreen
          class={[
            "w-full border-0",
            if(@media.provider == :youtube, do: "aspect-video", else: "h-40")
          ]}
          loading="lazy"
          referrerpolicy="strict-origin-when-cross-origin"
          src={@media.embed_url}
          title={@title}
        >
        </iframe>
      </div>

      <div :if={@map_embed_url} class="overflow-hidden rounded-box bg-base-300">
        <iframe
          allowfullscreen
          class="h-64 w-full border-0"
          data-testid="entry-location-map"
          loading="lazy"
          referrerpolicy="strict-origin-when-cross-origin"
          src={@map_embed_url}
          title={"Map for #{@title}"}
        >
        </iframe>
      </div>

      <div class="divide-y divide-base-content/10 pt-3">
        <section :if={@playlist.items != []} class="py-3 space-y-3">
          <h4 class="text-xs font-bold uppercase tracking-wide text-base-content/45">
            Playlist preview
          </h4>

          <ol
            aria-label="Playlist videos"
            class="space-y-0.5 text-xs sm:ml-26"
            data-testid="entry-playlist-items"
          >
            <li
              :for={{item, index} <- Enum.with_index(@playlist.items, 1)}
              class=""
            >
              <.link
                class="opacity-70 hover:opacity-100 transition hover:text-primary"
                data-testid={"entry-playlist-item-#{index}"}
                href={EntryPresentation.youtube_video_url(item.video_id)}
                rel="noopener noreferrer"
                target="_blank"
              >
                <span>{item.title}</span>
                <.icon name="hero-arrow-top-right-on-square-micro" class="size-3" />
              </.link>
            </li>
          </ol>

          <p
            :if={@playlist.remaining_count > 0}
            class="mt-2 pl-5 text-xs text-base-content/45"
            data-testid="entry-playlist-remaining"
          >
            …and {@playlist.remaining_count} more
          </p>
        </section>

        <div
          :for={field <- @type.fields}
          :if={not Schema.blank_value?(Schema.field_value(@entry, field))}
          class="grid gap-2 py-2 sm:grid-cols-[6rem_minmax(0,1fr)] items-baseline"
        >
          <div class="text-xs font-bold uppercase tracking-wide text-base-content/45">
            {field.label}
          </div>
          <div class="min-w-0 text-sm leading-tight">
            <.field_value field={field} value={Schema.field_value(@entry, field)} />
          </div>
        </div>
      </div>

      <section class="space-y-3 border-t border-base-content/10 pt-4" data-testid="entry-topics">
        <div class="flex items-center justify-between gap-3">
          <h3 class="text-sm font-bold">Topics</h3>
          <button
            class="btn btn-xs btn-ghost"
            data-testid="entry-topic-add-open"
            phx-click="topic:add"
            type="button"
          >
            <.icon name="hero-plus-micro" /> Add
          </button>
        </div>

        <div class="space-y-2">
          <div
            :for={summary <- @topic_summaries}
            class="flex items-center gap-2 rounded-box bg-base-200/55 px-3 py-2"
            data-testid={"entry-topic-detail-#{summary.tag.id}"}
          >
            <.icon :if={summary.automatic?} name="hero-sparkles-micro" class="size-3 text-primary" />
            <span class="min-w-0 flex-1 truncate text-sm font-medium">{summary.tag.name}</span>
            <span :if={!summary.automatic?} class="text-xs tabular-nums text-base-content/45">
              {summary.average_relevancy}/10
            </span>
            <button
              :if={summary.automatic?}
              aria-label={"Dismiss #{summary.tag.name}"}
              class="btn btn-xs btn-circle btn-ghost"
              data-testid={"entry-topic-dismiss-#{summary.tag.id}"}
              phx-click="topic:dismiss"
              phx-value-topic_id={summary.tag.id}
              type="button"
            >
              <.icon name="hero-x-mark-micro" />
            </button>
            <button
              :if={!summary.automatic? && summary.current_member_contribution}
              aria-label={"Remove #{summary.tag.name}"}
              class="btn btn-xs btn-circle btn-ghost"
              data-testid={"entry-topic-remove-#{summary.tag.id}"}
              phx-click="topic:remove"
              phx-value-topic_id={summary.tag.id}
              type="button"
            >
              <.icon name="hero-x-mark-micro" />
            </button>
          </div>
        </div>

        <.form
          :if={@topic_form}
          class="grid gap-3 rounded-box border border-base-content/10 p-3 sm:grid-cols-[1fr_10rem_auto] sm:items-end"
          data-testid="entry-topic-form"
          for={@topic_form}
          id="entry-topic-form"
          phx-submit="topic:save"
        >
          <.input
            field={@topic_form[:topic_id]}
            label="Topic"
            options={Enum.map(@topic_options, &{&1.name, &1.id})}
            prompt="Choose a topic"
            type="select"
          />
          <.input
            field={@topic_form[:relevancy]}
            label="Relevance"
            max="10"
            min="1"
            type="number"
          />
          <div class="flex gap-1">
            <button class="btn btn-sm btn-ghost" phx-click="topic:cancel" type="button">
              Cancel
            </button>
            <button class="btn btn-sm btn-primary" data-testid="entry-topic-save" type="submit">
              Save
            </button>
          </div>
        </.form>
      </section>

      <div :if={@manageable?} class="flex justify-end gap-2 border-t border-base-content/10 pt-4">
        <button
          class="btn btn-sm btn-ghost text-error"
          data-confirm="Delete this entry?"
          data-testid={"entry-delete-#{@entry.id}"}
          phx-click="entry:delete"
          phx-value-entry_id={@entry.id}
          type="button"
        >
          <.icon name="hero-trash-micro" /> Delete
        </button>
        <button
          class="btn btn-sm btn-primary"
          data-testid={"entry-edit-#{@entry.id}"}
          phx-click="entry:edit"
          phx-value-entry_id={@entry.id}
          type="button"
        >
          <.icon name="hero-pencil-square-micro" /> Edit
        </button>
      </div>
    </div>
    """
  end

  attr :field, :map, required: true
  attr :value, :any, required: true

  defp field_value(assigns) do
    ~H"""
    <.link
      :if={@field.type == :url}
      class="link link-primary break-all"
      href={@value}
      rel="noopener noreferrer"
      target="_blank"
    >
      {@value}
    </.link>
    <.link :if={@field.type == :email} class="link link-primary" href={"mailto:#{@value}"}>
      {@value}
    </.link>
    <.link :if={@field.type == :phone} class="link link-primary" href={"tel:#{@value}"}>
      {@value}
    </.link>
    <.link
      :if={@field.type == :location}
      class="link link-primary"
      href={"https://www.google.com/maps/search/?api=1&query=#{URI.encode_www_form(to_string(@value))}"}
      rel="noopener noreferrer"
      target="_blank"
    >
      {@value} <.icon name="hero-arrow-top-right-on-square-micro" />
    </.link>
    <span :if={@field.type == :select} class="badge badge-ghost">{@value}</span>
    <span :if={@field.type == :boolean}>{if(@value, do: "Yes", else: "No")}</span>
    <div
      :if={@field.type == :rich_text}
      class="prose prose-sm max-w-none"
    >
      {raw(markdown_to_html(to_string(@value)))}
    </div>
    <.link
      :if={@field.type == :media}
      class="link link-primary break-all"
      href={@value}
      rel="noopener noreferrer"
      target="_blank"
    >
      Open media <.icon name="hero-arrow-top-right-on-square-micro" />
    </.link>
    <span :if={@field.type in [:title, :text, :number, :date]}>{@value}</span>
    """
  end

  defp markdown_to_html(markdown) do
    MDEx.new(markdown: markdown)
    |> MDExGFM.attach()
    |> MDEx.to_html!(
      extension: [autolink: true, strikethrough: true, table: true, tasklist: true],
      render: [unsafe: true],
      sanitize: MDEx.Document.default_sanitize_options()
    )
  end
end
