defmodule WikWeb.LibraryPrototypeLive.Components.TypeWizard do
  use WikWeb, :html

  alias WikWeb.LibraryPrototypeLive.Components.TypePermissions
  alias WikWeb.LibraryPrototypeLive.FieldPresentation
  alias WikWeb.LibraryPrototypeLive.Schema

  attr :draft, :map, default: nil
  attr :form, :map, required: true
  attr :import_form, :map, required: true
  attr :templates, :list, required: true

  def render(assigns) do
    ~H"""
    <div class="space-y-6 max-w-[80ch] mx-auto" data-testid="type-wizard">
      <div :if={!@draft}>
        <h1 class="mb-4 text-2xl">Add type</h1>

        <div class="grid grid-cols-4 gap-1">
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
            <div class="flex justify-center">
              <span class="font-semibold small-caps">{template.name}</span>
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
          <h1 class="text-2xl font-semibold">Review type</h1>
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

          <TypePermissions.render
            id="type-create-permissions"
            name={@form[:entry_creation_permission].name}
            required
            selected={@form[:entry_creation_permission].value}
          />

          <div class="flex justify-between gap-3">
            <button class="btn btn-ghost opacity-50 hover:opacity-100 transition" phx-click="wizard:back" type="button">Back</button>
            <button class="btn btn-accent" data-testid="type-create-submit" type="submit">
              Create type 
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :fields, :list, required: true

  defp schema_summary(assigns) do
    ~H"""
    <div class="rounded-box border border-base-content/10 bg-base-200/40 p-5">
      <h2 class="text-xs font-bold uppercase tracking-wider text-base-content/45">Schema</h2>
      <div class="mt-3 divide-y divide-base-content/10">
        <div :for={field <- @fields} class="flex items-center gap-3 py-3 text-sm">
          <.icon name={FieldPresentation.schema_icon(field.type)} class="size-4 opacity-45" />
          <span class="font-semibold">{field.label}</span>
          <span class="badge badge-sm badge-ghost">{Schema.field_type_label(field.type)}</span>
          <span :if={field.required?} class="ml-auto text-xs text-error/70">Required</span>
        </div>
      </div>
    </div>
    """
  end
end
