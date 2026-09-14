defmodule WikWeb.LibraryPrototypeLive.Components.EntryDetail do
  use WikWeb, :html

  alias WikWeb.Components.UI
  alias WikWeb.LibraryPrototypeLive.EntryPresentation
  alias WikWeb.LibraryPrototypeLive.Schema

  attr :entry, :map, required: true

  def button_entry_edit(assigns) do
    ~H"""
    <UI.action_button
      data-tip="Edit"
      icon="hero-pencil-micro"
      data-testid={"entry-edit-#{@entry.id}"}
      phx-click="entry:edit"
      phx-value-entry_id={@entry.id}
    />
    """
  end

  attr :entry, :map, required: true

  def button_entry_delete(assigns) do
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

  attr :type, :map, required: true
  attr :entry, :map, required: true
  attr :manageable?, :boolean, required: true
  attr :playlist_label, :string, required: false
  attr :playlist_play_event, :string, default: "playlist:play"
  attr :selected_playlist_video_id, :string, default: nil
  attr :show_topics?, :boolean, default: true
  attr :topic_form, :map, default: nil
  attr :topic_options, :list, required: true
  attr :topic_summaries, :list, required: true

  def render(assigns) do
    media = EntryPresentation.media(assigns.type, assigns.entry)

    assigns =
      assigns
      |> assign(:map_embed_url, EntryPresentation.map_embed_url(assigns.type, assigns.entry))
      |> assign(:media, media)
      |> assign(:media_embed_url, media_embed_url(media, assigns.selected_playlist_video_id))
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
          src={@media_embed_url}
          data-testid="entry-media-player"
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

      <div
        :if={@manageable?}
        class="relative flex justify-end top-3 items-center gap-4"
      >
        <.button_entry_delete entry={@entry} />
        <.button_entry_edit entry={@entry} />
      </div>

      <div class="divide-y divide-base-content/10">
        <section :if={@playlist.items != []} class="pb-3">
          <div
            :if={@playlist_label}
            class={[
              "mb-2",
              "badge badge-sm bg-base-200",
              "text-xs small-caps text-base-content/60 whitespace-nowrap"
            ]}
            data-testid="entry-playlist-indicator"
          >
            {@playlist_label}
          </div>

          <ol
            aria-label="Playlist videos"
            class="text-xs"
            data-testid="entry-playlist-items"
          >
            <li :for={{item, index} <- Enum.with_index(@playlist.items, 1)}>
              <button
                aria-label={"Play #{item.title}"}
                aria-pressed={to_string(@selected_playlist_video_id == item.video_id)}
                class={[
                  "flex w-full items-center gap-1.5 rounded px-1.5 py-1 text-left",
                  "transition hover:bg-base-200 hover:text-primary",
                  "cursor-pointer",
                  if(@selected_playlist_video_id == item.video_id,
                    do: "bg-base-200 font-medium text-primary",
                    else: "opacity-70 hover:opacity-100"
                  )
                ]}
                data-testid={"entry-playlist-item-#{index}"}
                id={"entry-playlist-item-#{@entry.id}-#{index}"}
                phx-click={@playlist_play_event}
                phx-value-video_id={item.video_id}
                type="button"
              >
                <.icon name="hero-play-micro" class="size-3 shrink-0" />
                <span>{item.title}</span>
              </button>
            </li>
          </ol>

          <div
            :if={@playlist.remaining_count > 0}
            class="pl-6 text-xs"
            data-testid="entry-playlist-remaining"
          >
            <.link
              class={[
                "flex items-center gap-1",
                "hover:link",
                "pt-1",
                "opacity-80 hover:opacity-100 transition"
              ]}
              href={@playlist.source_url}
              rel="noopener noreferrer"
              target="_blank"
            >
              <span>…and {@playlist.remaining_count} more</span>
              <.icon name="hero-arrow-top-right-on-square-micro" class="opacity-60" />
            </.link>
          </div>
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

      <section
        :if={@show_topics?}
        class="space-y-3 border-t border-base-content/10 pt-4"
        data-testid="entry-topics"
      >
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
            <button
              class="btn btn-sm btn-accent btn-soft"
              data-testid="entry-topic-save"
              type="submit"
            >
              Save
            </button>
          </div>
        </.form>
      </section>
    </div>
    """
  end

  defp media_embed_url(%{embed_url: embed_url}, nil), do: embed_url
  defp media_embed_url(_media, nil), do: nil

  defp media_embed_url(_media, video_id) do
    EntryPresentation.youtube_video_embed_url(video_id)
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
