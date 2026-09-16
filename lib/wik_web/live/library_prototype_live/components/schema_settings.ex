defmodule WikWeb.LibraryPrototypeLive.Components.SchemaSettings do
  use WikWeb, :html

  alias WikWeb.Components.UI
  alias WikWeb.LibraryPrototypeLive.Components.TypePermissions
  alias WikWeb.LibraryPrototypeLive.FieldPresentation
  alias WikWeb.LibraryPrototypeLive.Schema

  attr :type, :map, required: true
  attr :type_form, :map, required: true
  attr :editing_field, :map, default: nil
  attr :field_form, :map, required: true
  attr :field_usage_counts, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="space-y-4" data-testid="schema-settings">
      <section class="rounded-box border border-base-content/10 bg-base-200/35 p-5">
        <.form
          class="space-y-5"
          data-testid="type-settings-form"
          for={@type_form}
          id="type-settings-form"
          phx-change="type:update_validate"
          phx-submit="type:update"
        >
          <div class="grid gap-4 sm:grid-cols-2">
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
          </div>

          <TypePermissions.render
            class="pt-4"
            field={@type_form[:entry_creation_permission]}
            id="type-settings-permissions"
            required
          />

          <div class="flex justify-end pt-4">
            <button class="btn btn-accent btn-soft" type="submit">Save changes</button>
          </div>
        </.form>
      </section>

      <section class="rounded-box border border-base-content/10 bg-base-200/35 p-5">
        <UI.panel_title>Fields</UI.panel_title>

        <div class="divide-y divide-base-content/10">
          <div
            :for={{field, index} <- Enum.with_index(@type.fields)}
            class="flex items-center gap-3 py-3"
            data-testid={"schema-field-#{field.key}"}
          >
            <span class="flex size-8 items-center justify-center rounded-lg bg-base-300">
              <.icon name={FieldPresentation.schema_icon(field.type)} class="size-4 opacity-55" />
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
                :if={index > 0}
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
                :if={index < length(@type.fields) - 1}
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
          phx-hook=".FocusFieldLabel"
          phx-submit={if(@editing_field, do: "field:update", else: "field:add")}
        >
          <.input field={@field_form[:label]} id="field-label" label="Field label" required />
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
            <button class="btn btn-accent btn-soft btn-sm" data-testid="field-submit" type="submit">
              {if(@editing_field, do: "Save field", else: "Add field")}
            </button>
          </div>
        </.form>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".FocusFieldLabel">
          export default {
            mounted() {
              this.handleEvent("field:focus-label", () => {
                this.el.querySelector("#field-label")?.focus()
              })
            }
          }
        </script>
      </section>
    </div>
    """
  end
end
