defmodule WikWeb.LibraryPrototypeLive.Components do
  use WikWeb, :html

  alias Wik.Blocks.Types.SoundCloud
  alias Wik.Blocks.Types.YouTube
  alias WikWeb.Components.LocationPicker
  alias WikWeb.Components.RichTextInput
  alias WikWeb.LibraryPrototypeLive.Schema

  attr :can_manage_collections?, :boolean, required: true
  attr :collections, :list, required: true
  attr :current_collection, :map, default: nil
  attr :space_slug, :string, required: true
  attr :live_action, :atom, required: true
  attr :current_scope, :map, required: true

  def collection_navigation(assigns) do
    ~H"""
    <nav aria-label="Collections" data-testid="library-navigation">
      <div class="mb-3 flex items-center justify-between px-1">
        <.link
          class="text-xs font-bold uppercase tracking-wider text-base-content/50 hover:text-base-content/70 transition"
          patch={~p"/#{@current_scope.tenant.slug}/libraries"}
        >
          Collections
        </.link>

        <.link
          :if={@can_manage_collections? and @live_action == :index}
          aria-label="Create collection"
          class="btn btn-accent btn-circle btn-xs btn-soft hover:btn-accent transition h-0"
          data-testid="collection-create-open"
          patch={~p"/#{@space_slug}/libraries/new"}
        >
          <.icon name="hero-plus-micro" />
        </.link>
      </div>

      <div class="max-md:flex max-md:flex-wrap max-md:gap-2 md:space-y-1">
        <.link
          :for={collection <- @collections}
          aria-current={
            if(@current_collection && collection.id == @current_collection.id, do: "page")
          }
          class={[
            "group flex shrink-0 items-center rounded px-3 py-2",
            "text-sm transition",
            @current_collection && collection.id == @current_collection.id &&
              "bg-base-content/10",
            (!@current_collection || collection.id != @current_collection.id) &&
              "bg-base-300/50 hover:bg-base-content/5"
          ]}
          data-testid={"collection-nav-#{collection.slug}"}
          patch={~p"/#{@space_slug}/libraries/#{collection.slug}"}
        >
          <span class="truncate font-medium whitespace-nowrap">{collection.name}</span>
        </.link>
      </div>
    </nav>
    """
  end

  attr :collection, :map, required: true
  attr :id, :string, required: true
  attr :space_slug, :string, required: true

  def collection_card(assigns) do
    ~H"""
    <.link
      id={@id}
      class={[
        "group card bg-base-300/45 shadow-sm",
        "transition hover:-translate-y-0.5 hover:border-primary/25 hover:shadow-md"
      ]}
      data-testid={"collection-card-#{@collection.slug}"}
      patch={~p"/#{@space_slug}/libraries/#{@collection.slug}"}
    >
      <div class="card-body gap-3 p-5">
        <div class="flex items-center justify-between gap-4">
          <h2 class="card-title text-base">{@collection.name}</h2>
          <span class="badge badge-sm badge-ghost text-base-content/50">
            {@collection.entry_count} entries
          </span>
        </div>
        <div>
          <p class="line-clamp-2 text-sm leading-relaxed text-base-content/55">
            {@collection.description}
          </p>
        </div>
      </div>
    </.link>
    """
  end

  attr :collection, :map, required: true
  attr :entry, :map, required: true
  attr :manageable?, :boolean, required: true
  attr :owned?, :boolean, required: true

  def entry_card(assigns) do
    assigns =
      assigns
      |> assign(:media, entry_media(assigns.collection, assigns.entry))
      |> assign(:media_field?, Enum.any?(assigns.collection.fields, &(&1.type == :media)))
      |> assign(:summary_fields, summary_fields(assigns.collection, assigns.entry))
      |> assign(:title, entry_title(assigns.collection, assigns.entry))

    ~H"""
    <article
      class={[
        "group overflow-hidden rounded-box border border-base-content/10 bg-base-200/50",
        "transition hover:border-primary/20 hover:bg-base-200/75 hover:shadow-md"
      ]}
      data-testid={"library-entry-#{@entry.id}"}
    >
      <button
        class={[
          "grid w-full cursor-pointer gap-4 p-4 text-left",
          if(@media_field?,
            do: "sm:grid-cols-[9rem_minmax(0,1fr)_auto]",
            else: "sm:grid-cols-[minmax(0,1fr)_auto]"
          )
        ]}
        data-testid={"entry-open-#{@entry.id}"}
        phx-click="entry:show"
        phx-value-entry_id={@entry.id}
        type="button"
      >
        <div
          :if={@media_field?}
          class="flex aspect-video items-center justify-center overflow-hidden rounded-lg bg-base-300"
          data-testid={"entry-media-#{@entry.id}"}
        >
          <img
            :if={@media && @media.thumbnail_url}
            alt=""
            class="h-full w-full object-cover opacity-80 transition group-hover:opacity-100"
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

        <div class="min-w-0 self-center">
          <h3 class="truncate font-bold text-base-content/85">{@title}</h3>
          <dl class="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-base-content/55">
            <div :for={field <- @summary_fields} class="flex min-w-0 gap-1">
              <dt class="font-semibold">{field.label}:</dt>
              <dd class="max-w-52 truncate">
                {display_value(Schema.field_value(@entry, field), field)}
              </dd>
            </div>
          </dl>
        </div>

        <div class="flex items-center gap-2 self-center">
          <span :if={@owned?} class="badge badge-sm badge-outline">Yours</span>
          <.icon
            name="hero-chevron-right-micro"
            class="size-5 opacity-25 transition group-hover:translate-x-0.5 group-hover:opacity-60"
          />
        </div>
      </button>
    </article>
    """
  end

  attr :collection, :map, required: true
  attr :entry, :map, required: true
  attr :manageable?, :boolean, required: true

  def entry_detail(assigns) do
    assigns =
      assigns
      |> assign(:media, entry_media(assigns.collection, assigns.entry))
      |> assign(:title, entry_title(assigns.collection, assigns.entry))

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
          :for={field <- @collection.fields}
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

  attr :draft, :map, default: nil
  attr :form, :map, required: true
  attr :import_form, :map, required: true
  attr :templates, :list, required: true

  def collection_wizard(assigns) do
    ~H"""
    <div class="space-y-8" data-testid="collection-wizard">
      <div :if={!@draft}>
        <div class="mb-5">
          <p class="text-sm font-semibold text-primary">Step 1 of 2</p>
          <h1 class="mt-1 text-2xl font-bold">What are you collecting?</h1>
          <p class="mt-2 text-sm text-base-content/55">
            Templates are starting points, but remain entirely configurable.
          </p>
        </div>

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
            label="Paste a collection schema"
            placeholder={~c"{\"format\": \"wik-library-schema\", ...}"}
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
          <p class="text-sm font-semibold text-primary">Step 2 of 2</p>
          <h1 class="mt-1 text-2xl font-bold">Review your collection</h1>
          <p class="mt-2 text-sm text-base-content/55">
            You can refine the schema from collection settings after creation.
          </p>
        </div>

        <.form
          class="space-y-6"
          data-testid="collection-create-form"
          for={@form}
          id="collection-create-form"
          phx-submit="collection:create"
        >
          <div class="grid gap-4 sm:grid-cols-2">
            <.input
              field={@form[:name]}
              label="Collection name"
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
            id="collection-create-permissions"
            name={@form[:entry_creation_permission].name}
            required
            selected={@form[:entry_creation_permission].value}
          />

          <div class="flex justify-between gap-3">
            <button class="btn btn-ghost" phx-click="wizard:back" type="button">Back</button>
            <button class="btn btn-primary" data-testid="collection-create-submit" type="submit">
              Create collection <.icon name="hero-arrow-right-micro" />
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
      data-testid="collection-permissions"
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

  attr :collection, :map, required: true
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
      <div :for={field <- @collection.fields}>
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

  attr :collection, :map, required: true
  attr :collection_form, :map, required: true
  attr :editing_field, :map, default: nil
  attr :field_form, :map, required: true
  attr :field_usage_counts, :map, required: true

  def schema_settings(assigns) do
    ~H"""
    <div class="space-y-8" data-testid="schema-settings">
      <section class="rounded-box border border-base-content/10 bg-base-200/35 p-5">
        <.form
          class="grid gap-4  sm:items-end"
          data-testid="collection-settings-form"
          for={@collection_form}
          id="collection-settings-form"
          phx-submit="collection:update"
        >
          <.input
            field={@collection_form[:name]}
            label="Name"
            phx-hook="CapitalizeFirstLetter"
            required
          />
          <.input
            field={@collection_form[:description]}
            label="Short description"
            phx-hook="CapitalizeFirstLetter"
          />
          <button class="btn btn-accent btn-soft" type="submit">Save</button>
        </.form>
      </section>

      <.entry_creation_permissions
        event="collection:entry_creation_permission:update"
        id="collection-settings-permissions"
        name="entry-creation-permission"
        selected={@collection.entry_creation_permission}
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
            :for={{field, index} <- Enum.with_index(@collection.fields)}
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
                :if={index > 0 && index < length(@collection.fields) - 1}
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
        <div>
          <h2 class="font-bold">Portable schema</h2>
          <p class="mt-1 text-sm text-base-content/50">
            Contains configuration only—never entries, owners, or space identifiers.
          </p>
        </div>
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
      <p class="mt-2 text-xs text-base-content/45">
        If automatic copying is unavailable, select the JSON above and copy it manually.
      </p>
    </section>
    """
  end

  def entry_title(collection, entry) do
    title_field = Enum.find(collection.fields, &(&1.type == :title))
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

  defp entry_media(collection, entry) do
    collection.fields
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

  defp summary_fields(collection, entry) do
    collection.fields
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
