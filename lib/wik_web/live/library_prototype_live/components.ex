defmodule WikWeb.LibraryPrototypeLive.Components do
  use WikWeb, :html

  alias Wik.Blocks.Types.SoundCloud
  alias Wik.Blocks.Types.YouTube
  alias WikWeb.Components.LocationPicker
  alias WikWeb.Components.RichTextInput
  alias WikWeb.LibraryPrototypeLive.Schema

  attr :active_topics, :list, required: true
  attr :active_types, :list, required: true
  attr :can_create_entry?, :boolean, required: true
  attr :can_manage_types?, :boolean, required: true
  attr :space_slug, :string, required: true
  attr :topics, :list, required: true
  attr :types, :list, required: true

  def library_toolbar(assigns) do
    ~H"""
    <header class="flex flex-wrap items-end justify-between gap-3" data-testid="library-toolbar">
      <div class="flex flex-wrap items-center gap-2" data-testid="library-filters">
        <.filter_menu
          icon="hero-tag-micro"
          items={@topics}
          kind="topic"
          selected_ids={Enum.map(@active_topics, & &1.id)}
          testid="topic-filter"
          title="Topics"
        />
        <.filter_menu
          icon="hero-circle-stack-micro"
          items={@types}
          kind="type"
          selected_ids={Enum.map(@active_types, & &1.id)}
          testid="type-filter"
          title="Types"
        />

        <button
          :for={topic <- @active_topics}
          class="badge badge-sm gap-1 border-primary/20 bg-primary/10 text-primary"
          data-testid={"active-topic-filter-#{topic.slug}"}
          phx-click="filter:toggle"
          phx-value-id={topic.id}
          phx-value-kind="topic"
          type="button"
        >
          {topic.name} <.icon name="hero-x-mark-micro" class="size-3" />
        </button>
        <button
          :for={type <- @active_types}
          class="badge badge-sm gap-1"
          data-testid={"active-type-filter-#{type.slug}"}
          phx-click="filter:toggle"
          phx-value-id={type.id}
          phx-value-kind="type"
          type="button"
        >
          {type.name} <.icon name="hero-x-mark-micro" class="size-3" />
        </button>
      </div>
      <div class="flex items-center gap-2">
        <button
          :if={@can_manage_types?}
          aria-label="Library settings"
          class="btn btn-sm btn-circle btn-ghost"
          data-testid="library-settings-open"
          popovertarget="library-settings-popover"
          style="anchor-name:--library-settings-anchor"
          type="button"
        >
          <.icon name="hero-cog-6-tooth-micro" />
        </button>
        <ul
          :if={@can_manage_types?}
          class="dropdown dropdown-end menu z-20 w-48 rounded-box bg-base-300 shadow-sm"
          id="library-settings-popover"
          popover
          style="position-anchor:--library-settings-anchor"
        >
          <li>
            <.link data-testid="types-manage-open" patch={~p"/#{@space_slug}/libraries/types"}>
              <.icon name="hero-circle-stack-micro" /> Types
            </.link>
          </li>
          <li>
            <.link
              data-testid="topic-matching-open"
              patch={~p"/#{@space_slug}/libraries/topic-matching"}
            >
              <.icon name="hero-sparkles-micro" /> Smart topics
            </.link>
          </li>
        </ul>
        <button
          :if={@can_create_entry?}
          class="btn btn-sm btn-primary"
          data-testid="entry-create-open"
          phx-click="entry:new"
          type="button"
        >
          <.icon name="hero-plus-micro" /> Add entry
        </button>
      </div>
    </header>
    """
  end

  attr :icon, :string, required: true
  attr :items, :list, required: true
  attr :kind, :string, required: true
  attr :selected_ids, :list, required: true
  attr :testid, :string, required: true
  attr :title, :string, required: true

  defp filter_menu(assigns) do
    ~H"""
    <button
      class="btn btn-sm btn-ghost bg-base-200"
      data-testid={@testid}
      popovertarget={"#{@testid}-popover"}
      style={"anchor-name:--#{@testid}-anchor"}
      type="button"
    >
      <.icon name={@icon} /> {@title}
      <.icon name="hero-chevron-down-micro" />
    </button>
    <ul
      class="dropdown menu z-20 max-h-72 w-56 overflow-y-auto rounded-box bg-base-300"
      id={"#{@testid}-popover"}
      popover
      style={"position-anchor:--#{@testid}-anchor"}
    >
      <li :for={item <- @items}>
        <button
          data-testid={"#{@testid}-#{item.slug}"}
          phx-click="filter:toggle"
          phx-value-id={item.id}
          phx-value-kind={@kind}
          type="button"
        >
          <.icon
            name={
              if(@selected_ids == [] or item.id in @selected_ids,
                do: "hero-check-micro",
                else: "hero-minus-micro"
              )
            }
            class={
              if(@selected_ids == [] or item.id in @selected_ids,
                do: "text-success",
                else: "opacity-20"
              )
            }
          />
          <span class="truncate">{item.name}</span>
        </button>
      </li>
    </ul>
    """
  end

  attr :types, :list, required: true

  def type_picker(assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-2 sm:grid-cols-4" data-testid="entry-type-picker">
      <button
        :for={type <- @types}
        class="group rounded-box bg-base-200 p-4 text-left transition hover:bg-base-300 cursor-pointer"
        data-testid={"entry-type-select-#{type.slug}"}
        phx-click="entry:type"
        phx-value-type_id={type.id}
        type="button"
      >
        <span class="font-semibold">{type.name}</span>
      </button>
    </div>
    """
  end

  attr :space_slug, :string, required: true
  attr :types, :list, required: true

  def type_list(assigns) do
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

  attr :type, :map, required: true
  attr :entry, :map, required: true
  attr :manageable?, :boolean, required: true
  attr :owned?, :boolean, required: true
  attr :topic_summaries, :list, required: true

  def entry_card(assigns) do
    assigns =
      assigns
      |> assign(:media, entry_media(assigns.type, assigns.entry))
      |> assign(:media_field?, Enum.any?(assigns.type.fields, &(&1.type == :media)))
      |> assign(:summary_fields, summary_fields(assigns.type, assigns.entry))
      |> assign(:title, entry_title(assigns.type, assigns.entry))

    ~H"""
    <div class="flex gap-2 pt-4 pl-4 mb-4 pr-2">
      <h3 class="leading-none text-balance Xself-end line-clamp-2 font-bold text-base-content/85">
        {@title}
      </h3>
      <span class="ml-auto badge badge-xs badge-ghost shrink-0">{@type.name}</span>
    </div>

    <div
      :if={@media_field?}
      class="row-span-4 px-4 mb-4"
      data-testid={"entry-media-#{@entry.id}"}
    >
      <div class="flex aspect-video items-center justify-center overflow-hidden rounded bg-base-300">
        <img
          :if={@media && @media.thumbnail_url}
          alt=""
          class="h-full w-full object-cover opacity-80 transition"
          loading="lazy"
          src={@media.thumbnail_url}
        />
        <.icon
          :if={@media && !@media.thumbnail_url}
          name={if(@media.provider == :soundcloud, do: "hero-musical-note", else: "hero-link")}
          class="size-8 opacity-25"
        />
        <.icon :if={!@media} name="hero-document-text" class="size-8 opacity-20" />
      </div>
    </div>
    <div class="space-y-2 px-4">
      <dl class="space-y-1 text-xs text-base-content/55">
        <div :for={field <- @summary_fields} class="flex min-w-0 gap-1">
          <dt class="flex items-center font-semibold" title={field.label}>
            <%= if icon = entry_field_icon(field) do %>
              <.icon name={icon} class="size-3.5" />
              <span class="sr-only">{field.label}:</span>
            <% else %>
              {field.label}:
            <% end %>
          </dt>
          <dd class="max-w-52 truncate">
            {display_value(Schema.field_value(@entry, field), field)}
          </dd>
        </div>
      </dl>
    </div>

    <div class="flex items-center gap-2 self-center">
      <span :if={@owned?} class="badge badge-sm badge-outline">Yours</span>
    </div>

    <div class="px-4 pb-4">
      <div :if={@topic_summaries != []} class="flex flex-wrap gap-1.5">
        <span
          :for={summary <- Enum.take(@topic_summaries, 6)}
          class="badge badge-sm gap-1 border-primary/15 bg-primary/8 text-primary"
          data-testid={"entry-topic-#{@entry.id}-#{summary.tag.id}"}
        >
          <.icon :if={summary.automatic?} name="hero-sparkles-micro" class="size-3" />
          {summary.tag.name}
        </span>
        <span :if={length(@topic_summaries) > 6} class="badge badge-sm badge-ghost">
          +{length(@topic_summaries) - 6}
        </span>
      </div>
    </div>
    """
  end

  attr :type, :map, required: true
  attr :entry, :map, required: true
  attr :manageable?, :boolean, required: true
  attr :topic_form, :map, default: nil
  attr :topic_options, :list, required: true
  attr :topic_summaries, :list, required: true

  def entry_detail(assigns) do
    assigns =
      assigns
      |> assign(:media, entry_media(assigns.type, assigns.entry))
      |> assign(:title, entry_title(assigns.type, assigns.entry))

    ~H"""
    <div class="space-y-6" data-testid={"library-entry-detail-#{@entry.id}"}>
      <div :if={@media && @media.embed_url} class="overflow-hidden rounded-box bg-black">
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

      <dl class="divide-y divide-base-content/10">
        <div
          :for={field <- @type.fields}
          :if={not Schema.blank_value?(Schema.field_value(@entry, field))}
          class="grid gap-2 py-4 sm:grid-cols-[9rem_minmax(0,1fr)]"
        >
          <dt class="text-xs font-bold uppercase tracking-wide text-base-content/45">
            {field.label}
          </dt>
          <dd class="min-w-0 text-sm leading-relaxed">
            <.field_value field={field} value={Schema.field_value(@entry, field)} />
          </dd>
        </div>
      </dl>

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

  def field_value(assigns) do
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

  attr :automatic_topic_matching?, :boolean, required: true
  attr :expanded_topic_id, :string, default: nil
  attr :space_slug, :string, required: true
  attr :topic_views, :list, required: true

  def topic_matching(assigns) do
    ~H"""
    <div class="space-y-4" data-testid="topic-matching-page">
      <div class="flex items-center justify-between gap-3">
        <h1 class="text-2xl flex items-center gap-2 text-base-content/80">
          <.icon name="hero-sparkles-micro" class="size-5" /> Smart topics
        </h1>
        <button
          aria-checked={to_string(@automatic_topic_matching?)}
          class={[
            "btn btn-sm rounded-full",
            @automatic_topic_matching? && "btn-primary",
            !@automatic_topic_matching? && "btn-ghost bg-base-200"
          ]}
          data-testid="topic-matching-toggle"
          phx-click="matching:toggle"
          role="switch"
          type="button"
        >
          {if(@automatic_topic_matching?, do: "On", else: "Off")}
        </button>
      </div>

      <div
        :if={@topic_views == []}
        class="rounded-box bg-base-200/55 px-4 py-6 text-center text-sm"
        data-testid="topic-matching-empty"
      >
        <.link class="link link-primary" navigate={~p"/#{@space_slug}/topics"}>Create a topic</.link>
      </div>

      <div class="divide-y divide-base-content/10 rounded-box bg-base-200/40 px-4">
        <div :for={view <- @topic_views} data-testid={"topic-matching-rule-#{view.topic.slug}"}>
          <div class="flex items-center gap-2 py-3">
            <button
              aria-expanded={to_string(@expanded_topic_id == view.topic.id)}
              class="flex min-w-0 flex-1 items-center gap-2 text-left"
              data-testid={"topic-matching-expand-#{view.topic.slug}"}
              phx-click="matching:expand"
              phx-value-topic_id={view.topic.id}
              type="button"
            >
              <.icon
                name={
                  if(@expanded_topic_id == view.topic.id,
                    do: "hero-chevron-down-micro",
                    else: "hero-chevron-right-micro"
                  )
                }
                class="size-3 opacity-40"
              />
              <span class="truncate text-sm font-medium">{view.topic.name}</span>
              <span class="badge badge-xs badge-ghost">{view.count}</span>
            </button>
            <button
              aria-checked={to_string(view.rule.enabled?)}
              class={[
                "btn btn-xs rounded-full",
                view.rule.enabled? && "btn-primary btn-soft",
                !view.rule.enabled? && "btn-ghost opacity-60"
              ]}
              data-testid={"topic-matching-rule-toggle-#{view.topic.slug}"}
              phx-click="matching:rule:toggle"
              phx-value-topic_id={view.topic.id}
              role="switch"
              type="button"
            >
              {if(view.rule.enabled?, do: "Enabled", else: "Disabled")}
            </button>
          </div>

          <div :if={@expanded_topic_id == view.topic.id} class="space-y-3 pb-4 pl-5">
            <div :if={view.rule.aliases != []} class="flex flex-wrap gap-1.5">
              <button
                :for={alias_value <- view.rule.aliases}
                class="badge badge-sm gap-1"
                data-testid={"topic-matching-alias-#{view.topic.slug}"}
                phx-click="matching:alias:remove"
                phx-value-alias={alias_value}
                phx-value-topic_id={view.topic.id}
                type="button"
              >
                {alias_value} <.icon name="hero-x-mark-micro" class="size-3" />
              </button>
            </div>
            <.form
              class="flex gap-2"
              data-testid={"topic-matching-alias-form-#{view.topic.slug}"}
              for={to_form(%{"value" => ""}, as: :topic_alias)}
              id={"topic-matching-alias-form-#{view.topic.id}"}
              phx-submit="matching:alias:add"
            >
              <input name="topic_id" type="hidden" value={view.topic.id} />
              <.input
                aria-label="Alias"
                class="input input-sm flex-1"
                field={to_form(%{"value" => ""}, as: :topic_alias)[:value]}
                placeholder="Alias"
              />
              <button class="btn btn-sm btn-ghost" type="submit">Add</button>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :draft, :map, default: nil
  attr :form, :map, required: true
  attr :import_form, :map, required: true
  attr :templates, :list, required: true

  def type_wizard(assigns) do
    ~H"""
    <div class="space-y-6" data-testid="type-wizard">
      <div :if={!@draft}>
        <h1 class="mb-5 text-2xl font-bold">Add type</h1>

        <div class="grid grid-cols-2 gap-1 xl:grid-cols-4">
          <button
            :for={template <- @templates}
            class={[
              "group rounded-box bg-base-300/45 p-5 text-left",
              "cursor-pointer transition hover:-translate-y-0.5 hover:border-primary/30 hover:shadow-md"
            ]}
            data-testid={"template-select-#{template.id}"}
            phx-click="wizard:select"
            phx-value-template_id={template.id}
            type="button"
          >
            <div class="flex items-center gap-3">
              <span class="rounded-box bg-primary/10 p-2 text-primary">
                <.icon name={template.icon} class="size-5" />
              </span>
              <span class="font-bold">{template.name}</span>
            </div>
          </button>
        </div>

        <div class="divider text-xs uppercase tracking-widest text-base-content/85">
          or import one
        </div>

        <.form
          class="rounded-box border border-dashed border-base-content/20 bg-base-200/25 p-5"
          data-testid="schema-import-form"
          for={@import_form}
          id="schema-import-form"
          phx-submit="schema:import"
        >
          <.input
            field={@import_form[:json]}
            label="Paste a type schema"
            placeholder={~c"{\"format\": \"wik-library-type\", ...}"}
            rows="7"
            type="textarea"
          />
          <div class="mt-3 flex justify-end">
            <button class="btn btn-sm btn-outline" data-testid="schema-import-submit" type="submit">
              <.icon name="hero-arrow-down-tray-micro" /> Validate schema
            </button>
          </div>
        </.form>
      </div>

      <div :if={@draft} class="mx-auto max-w-3xl">
        <div class="mb-5">
          <h1 class="text-2xl font-bold">Review type</h1>
        </div>

        <.form
          class="space-y-6"
          data-testid="type-create-form"
          for={@form}
          id="type-create-form"
          phx-submit="type:create"
        >
          <div class="grid gap-4 sm:grid-cols-2">
            <.input
              field={@form[:name]}
              label="Type name"
              phx-hook="CapitalizeFirstLetter"
              required
            />
            <.input
              field={@form[:description]}
              label="Short description"
              phx-hook="CapitalizeFirstLetter"
            />
          </div>

          <.schema_summary fields={@draft.fields} />

          <.entry_creation_permissions
            id="type-create-permissions"
            name={@form[:entry_creation_permission].name}
            required
            selected={@form[:entry_creation_permission].value}
          />

          <div class="flex justify-between gap-3">
            <button class="btn btn-ghost" phx-click="wizard:back" type="button">Back</button>
            <button class="btn btn-primary" data-testid="type-create-submit" type="submit">
              Create type <.icon name="hero-arrow-right-micro" />
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :event, :string, default: nil
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :required, :boolean, default: false
  attr :selected, :any, default: nil

  def entry_creation_permissions(assigns) do
    ~H"""
    <section
      class="rounded-box border border-base-content/10 bg-base-200/35 p-5"
      data-testid="type-permissions"
      id={@id}
    >
      <h2 class="text-lg font-bold">Permissions</h2>
      <p class="mt-1 text-sm text-base-content/50">Who can add entries?</p>

      <fieldset class="mt-4 grid gap-2 sm:grid-cols-2">
        <legend class="sr-only">Who can add entries?</legend>
        <label class={[
          "flex cursor-pointer items-center gap-3 rounded-box border p-3 transition-colors",
          if(to_string(@selected) == "members",
            do: "border-accent/40 bg-accent/5",
            else: "border-base-content/10 hover:bg-base-200"
          )
        ]}>
          <input
            checked={to_string(@selected) == "members"}
            class="radio radio-sm radio-accent"
            data-testid="entry-creation-permission-members"
            id={"#{@id}-members"}
            name={@name}
            phx-click={@event}
            phx-value-permission="members"
            required={@required}
            type="radio"
            value="members"
          />
          <span class="font-medium">Any member</span>
        </label>

        <label class={[
          "flex cursor-pointer items-center gap-3 rounded-box border p-3 transition-colors",
          if(to_string(@selected) == "admins",
            do: "border-accent/40 bg-accent/5",
            else: "border-base-content/10 hover:bg-base-200"
          )
        ]}>
          <input
            checked={to_string(@selected) == "admins"}
            class="radio radio-sm radio-accent"
            data-testid="entry-creation-permission-admins"
            id={"#{@id}-admins"}
            name={@name}
            phx-click={@event}
            phx-value-permission="admins"
            type="radio"
            value="admins"
          />
          <span class="font-medium">Owner and admins</span>
        </label>
      </fieldset>
    </section>
    """
  end

  attr :fields, :list, required: true

  def schema_summary(assigns) do
    ~H"""
    <div class="rounded-box border border-base-content/10 bg-base-200/40 p-5">
      <h2 class="text-xs font-bold uppercase tracking-wider text-base-content/45">Schema</h2>
      <div class="mt-3 divide-y divide-base-content/10">
        <div :for={field <- @fields} class="flex items-center gap-3 py-3 text-sm">
          <.icon name={field_icon(field.type)} class="size-4 opacity-45" />
          <span class="font-semibold">{field.label}</span>
          <span class="badge badge-sm badge-ghost">{Schema.field_type_label(field.type)}</span>
          <span :if={field.required?} class="ml-auto text-xs text-error/70">Required</span>
        </div>
      </div>
    </div>
    """
  end

  attr :type, :map, required: true
  attr :form, :map, required: true
  attr :mode, :atom, required: true

  def entry_form(assigns) do
    ~H"""
    <.form
      class="space-y-5"
      data-testid="entry-form"
      for={@form}
      id="entry-form"
      phx-submit={if(@mode == :new, do: "entry:create", else: "entry:update")}
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
          field={@form[field.key]}
          label={field.label}
          options={if(field.type == :select, do: Enum.map(field.options, &{&1, &1}), else: [])}
          prompt={
            if(field.type == :select and not field.required?, do: "Choose an option", else: nil)
          }
          required={field.required?}
          type={input_type(field.type)}
        />
      </div>

      <div class="flex justify-end gap-2 border-t border-base-content/10 pt-4">
        <button class="btn btn-ghost" phx-click="modal:close" type="button">Cancel</button>
        <button class="btn btn-primary" data-testid="entry-submit" type="submit">
          {if(@mode == :new, do: "Add entry", else: "Save entry")}
        </button>
      </div>
    </.form>
    """
  end

  attr :type, :map, required: true
  attr :type_form, :map, required: true
  attr :editing_field, :map, default: nil
  attr :field_form, :map, required: true
  attr :field_usage_counts, :map, required: true

  def schema_settings(assigns) do
    ~H"""
    <div class="space-y-8" data-testid="schema-settings">
      <section class="rounded-box border border-base-content/10 bg-base-200/35 p-5">
        <.form
          class="grid gap-4  sm:items-end"
          data-testid="type-settings-form"
          for={@type_form}
          id="type-settings-form"
          phx-submit="type:update"
        >
          <.input
            field={@type_form[:name]}
            label="Name"
            phx-hook="CapitalizeFirstLetter"
            required
          />
          <.input
            field={@type_form[:description]}
            label="Short description"
            phx-hook="CapitalizeFirstLetter"
          />
          <button class="btn btn-accent btn-soft" type="submit">Save</button>
        </.form>
      </section>

      <.entry_creation_permissions
        event="type:entry_creation_permission:update"
        id="type-settings-permissions"
        name="entry-creation-permission"
        selected={@type.entry_creation_permission}
      />

      <section class="rounded-box border border-base-content/10 bg-base-200/35 p-5">
        <div class="flex items-center justify-between gap-4">
          <div>
            <h2 class="text-lg font-bold">Fields</h2>
            <p class="mt-1 text-sm text-base-content/50">Cards and details follow this order.</p>
          </div>
        </div>

        <div class="mt-5 divide-y divide-base-content/10">
          <div
            :for={{field, index} <- Enum.with_index(@type.fields)}
            class="flex items-center gap-3 py-3"
            data-testid={"schema-field-#{field.key}"}
          >
            <span class="flex size-8 items-center justify-center rounded-lg bg-base-300">
              <.icon name={field_icon(field.type)} class="size-4 opacity-55" />
            </span>
            <div class="min-w-0 flex-1">
              <div class="flex flex-wrap items-center gap-2">
                <span class="font-semibold">{field.label}</span>
                <span class="badge badge-sm badge-ghost">{Schema.field_type_label(field.type)}</span>
                <span :if={field.required?} class="text-xs text-error/70">Required</span>
                <span class="text-xs text-base-content/35">
                  {Map.get(@field_usage_counts, field.id, 0)} populated
                </span>
              </div>
              <p :if={field.type == :select} class="mt-1 truncate text-xs text-base-content/45">
                {Enum.join(field.options, ", ")}
              </p>
            </div>
            <div class="flex items-center gap-1">
              <button
                :if={index > 1}
                aria-label={"Move #{field.label} up"}
                class="btn btn-square btn-ghost btn-xs"
                phx-click="field:move"
                phx-value-direction="up"
                phx-value-field_id={field.id}
                type="button"
              >
                <.icon name="hero-chevron-up-micro" />
              </button>
              <button
                :if={index > 0 && index < length(@type.fields) - 1}
                aria-label={"Move #{field.label} down"}
                class="btn btn-square btn-ghost btn-xs"
                phx-click="field:move"
                phx-value-direction="down"
                phx-value-field_id={field.id}
                type="button"
              >
                <.icon name="hero-chevron-down-micro" />
              </button>
              <button
                aria-label={"Edit #{field.label}"}
                class="btn btn-square btn-ghost btn-xs"
                data-testid={"field-edit-#{field.key}"}
                phx-click="field:edit"
                phx-value-field_id={field.id}
                type="button"
              >
                <.icon name="hero-pencil-square-micro" />
              </button>
              <button
                :if={field.type != :title}
                aria-label={"Delete #{field.label}"}
                class="btn btn-square btn-ghost btn-xs text-error"
                data-confirm={
                  "Delete #{field.label}? #{Map.get(@field_usage_counts, field.id, 0)} populated values will be removed."
                }
                data-testid={"field-delete-#{field.key}"}
                phx-click="field:delete"
                phx-value-field_id={field.id}
                type="button"
              >
                <.icon name="hero-trash-micro" />
              </button>
            </div>
          </div>
        </div>

        <.form
          class="mt-5 grid gap-3 rounded-box border border-dashed border-base-content/20 p-4 sm:grid-cols-2"
          data-testid="field-form"
          for={@field_form}
          id="field-form"
          phx-change="field:change"
          phx-submit={if(@editing_field, do: "field:update", else: "field:add")}
        >
          <.input field={@field_form[:label]} label="Field label" required />
          <div :if={@editing_field && @editing_field.type == :title} class="fieldset">
            <span class="label">Field type</span>
            <div class="input flex items-center text-base-content/55">Title</div>
          </div>
          <.input
            :if={!@editing_field || @editing_field.type != :title}
            field={@field_form[:type]}
            label="Field type"
            options={Schema.field_type_options()}
            type="select"
          />
          <.input
            :if={@field_form[:type].value == "select"}
            field={@field_form[:options]}
            label="Select options (comma-separated)"
            placeholder="Beginner, Intermediate, Advanced"
          />
          <.input
            disabled={@editing_field && @editing_field.type == :title}
            field={@field_form[:required]}
            label="Required"
            type="checkbox"
          />
          <div class="flex justify-end gap-2 sm:col-span-2">
            <button
              :if={@editing_field}
              class="btn btn-ghost btn-sm"
              phx-click="field:cancel"
              type="button"
            >
              Cancel edit
            </button>
            <button class="btn btn-primary btn-sm" data-testid="field-submit" type="submit">
              {if(@editing_field, do: "Save field", else: "Add field")}
            </button>
          </div>
        </.form>
      </section>
    </div>
    """
  end

  attr :export_json, :string, required: true

  def portable_schema(assigns) do
    ~H"""
    <section
      class="rounded-box border border-base-content/10 bg-base-200/40 p-5"
      data-testid="portable-schema"
    >
      <div class="flex items-center justify-between gap-4">
        <h2 class="font-bold">Portable schema</h2>
        <button
          class="btn btn-sm btn-primary"
          data-copy-source-id="library-schema-json"
          data-testid="schema-copy"
          id="library-schema-copy"
          phx-hook="CopyToClipboard"
          type="button"
        >
          <.icon name="hero-clipboard-document-micro" /> Copy JSON
        </button>
      </div>
      <textarea
        id="library-schema-json"
        class="textarea mt-4 h-80 w-full font-mono text-xs leading-relaxed"
        readonly
      >{@export_json}</textarea>
    </section>
    """
  end

  def entry_title(type, entry) do
    title_field = Enum.find(type.fields, &(&1.type == :title))
    Schema.field_value(entry, title_field) || "Untitled"
  end

  def media_embed(value) when is_binary(value) do
    with {:error, _message} <- YouTube.normalize_embed_input(value),
         {:error, _message} <- soundcloud_embed(value) do
      nil
    else
      {:ok, ""} -> nil
      {:ok, embed_url} -> media_provider(embed_url)
    end
  end

  def media_embed(_value), do: nil

  defp entry_media(type, entry) do
    type.fields
    |> Enum.find(&(&1.type == :media and not Schema.blank_value?(Schema.field_value(entry, &1))))
    |> case do
      nil ->
        nil

      field ->
        media_embed(Schema.field_value(entry, field)) ||
          %{embed_url: nil, provider: :link, thumbnail_url: nil}
    end
  end

  defp soundcloud_embed(value) do
    case URI.parse(value) do
      %URI{host: host, scheme: "https"} when host in ["soundcloud.com", "www.soundcloud.com"] ->
        SoundCloud.normalize_embed_input(
          "https://w.soundcloud.com/player/?url=#{URI.encode_www_form(value)}"
        )

      _uri ->
        SoundCloud.normalize_embed_input(value)
    end
  end

  defp media_provider("https://www.youtube-nocookie.com/embed/" <> video_id = embed_url) do
    %{
      embed_url: embed_url,
      provider: :youtube,
      thumbnail_url: "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg"
    }
  end

  defp media_provider("https://w.soundcloud.com/player" <> _rest = embed_url) do
    %{embed_url: embed_url, provider: :soundcloud, thumbnail_url: nil}
  end

  defp media_provider(_embed_url), do: nil

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

  defp input_type(:boolean), do: "checkbox"
  defp input_type(:date), do: "date"
  defp input_type(:email), do: "email"
  defp input_type(:media), do: "url"
  defp input_type(:number), do: "number"
  defp input_type(:phone), do: "tel"
  defp input_type(:select), do: "select"
  defp input_type(:url), do: "url"
  defp input_type(_type), do: "text"

  defp entry_field_icon(%{key: "organization"}), do: "hero-home"
  defp entry_field_icon(%{key: "role"}), do: "hero-academic-cap"
  defp entry_field_icon(%{type: :text}), do: nil
  defp entry_field_icon(%{type: type}), do: field_icon(type)

  defp field_icon(:boolean), do: "hero-check-circle-micro"
  defp field_icon(:date), do: "hero-calendar-days-micro"
  defp field_icon(:email), do: "hero-envelope-micro"
  defp field_icon(:location), do: "hero-map-pin-micro"
  defp field_icon(:media), do: "hero-play-circle-micro"
  defp field_icon(:number), do: "hero-hashtag-micro"
  defp field_icon(:phone), do: "hero-phone-micro"
  defp field_icon(:rich_text), do: "hero-document-text-micro"
  defp field_icon(:select), do: "hero-chevron-up-down-micro"
  defp field_icon(:title), do: "hero-key-micro"
  defp field_icon(:url), do: "hero-link-micro"
  defp field_icon(_type), do: "hero-bars-3-bottom-left-micro"

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
