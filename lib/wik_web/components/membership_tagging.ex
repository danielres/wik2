defmodule WikWeb.Components.MembershipTagging do
  use Phoenix.Component
  use WikWeb, :live_view
  import Phoenix.Component, except: [form: 1]

  alias Wik.Tags.Dimensions
  alias Wik.Tags.Tagging
  alias WikWeb.Cinder.Themes.Dense
  alias WikWeb.Components.UI

  attr :editable?, :boolean, required: true
  attr :query, :any, required: true
  attr :scope, :map, required: true
  attr :url_state, :any, default: false

  def table(assigns) do
    assigns =
      assign(assigns,
        interest_dimension: dimension("interest"),
        skill_dimension: dimension("skill")
      )

    ~H"""
    <div
      :if={@query != nil}
      class="overflow-hidden rounded border border-base-300 bg-base-content/3"
      data-testid="member-taggings-table"
    >
      <Cinder.collection
        id="member-taggings"
        page_size={100}
        query={@query}
        scope={@scope}
        show_filters={false}
        sort_mode="exclusive"
        theme={Dense}
        url_state={@url_state}
      >
        <:col :let={tagging} field="tag.name" label="Tag" sort>
          <div class="" data-testid={"member-tagging-row-#{tagging.tag_id}"}>
            <div data-testid={"member-tagging-name-#{tagging.tag_id}"}>
              {tagging.tag.name}
            </div>
            <div
              :if={present?(tagging.description)}
              class="mt-1 text-xs opacity-60 max-h-20 overflow-y-auto pr-2 text-balance"
              data-testid={"member-tagging-description-#{tagging.tag_id}"}
            >
              <div class="whitespace-pre-wrap">{tagging.description}</div>
            </div>
          </div>
        </:col>

        <:col
          :let={tagging}
          field="interest_level"
          label={@interest_dimension.label}
          sort={[cycle: [:desc_nils_last]]}
          class="w-32"
        >
          <.level_meter
            :if={dimension_level(tagging, "interest")}
            dimension={@interest_dimension}
            label={@interest_dimension.label}
            level={dimension_level(tagging, "interest")}
            testid={"member-tagging-interest-#{tagging.tag_id}"}
          />
        </:col>

        <:col
          :let={tagging}
          field="skill_level"
          label={@skill_dimension.label}
          sort={[cycle: [:desc_nils_last]]}
          class="w-32"
        >
          <.level_meter
            :if={dimension_level(tagging, "skill")}
            dimension={@skill_dimension}
            label={@skill_dimension.label}
            level={dimension_level(tagging, "skill")}
            testid={"member-tagging-skill-#{tagging.tag_id}"}
          />
        </:col>

        <:col :let={tagging} label="">
          <div :if={@editable?} class="flex items-center gap-2 justify-end">
            <button
              class="btn btn-xs btn-soft btn-accent btn-circle"
              data-testid={"member-tagging-edit-#{tagging.tag_id}"}
              phx-click="tagging_edit_start"
              phx-value-tag_id={tagging.tag_id}
              type="button"
            >
              <.icon name="hero-pencil-mini" class="size-3" />
            </button>
          </div>
        </:col>
      </Cinder.collection>
    </div>
    """
  end

  attr :action_label, :string, required: true
  attr :error, :string, default: nil
  attr :form, :any, required: true
  attr :membership, :map, required: true
  attr :mode, :atom, required: true
  attr :options, :list, required: true
  attr :tag_id, :string, default: nil
  attr :tag_name, :string, default: nil
  attr :tenant, :map, required: true

  def form(assigns) do
    assigns =
      assign(assigns,
        interest_dimension: dimension("interest"),
        skill_dimension: dimension("skill")
      )

    ~H"""
    <div data-testid="member-tagging-form">
      <Phoenix.Component.form
        for={@form}
        id="member-tagging-form"
        data-testid="member-tagging-form-form"
        phx-change="tagging_validate"
        phx-submit="tagging_submit"
      >
        <div class="space-y-6 rounded-box bg-base-100 ">
          <.input
            :if={@mode == :create}
            field={@form[:tag_id]}
            label="Tag"
            options={Enum.map(@options, &{&1.name, &1.id})}
            prompt="Select a tag"
            type="select"
          />
          <input
            :if={@mode == :edit}
            type="hidden"
            name={@form[:tag_id].name}
            value={@form[:tag_id].value}
          />

          <div :if={@mode == :edit} class="space-y-1">
            <div class="flex items-center gap-2">
              <WikWeb.Components.User.avatar
                membership={@membership}
                size="md"
                tenant={@tenant}
                tooltip?
                tooltip_direction="right"
              />
              <.icon name="hero-arrows-right-left-micro" />
              <UI.page_title class="text-lg">
                {@tag_name}
              </UI.page_title>
            </div>
          </div>

          <.range_input
            field={@form[:interest_level]}
            dimension={@interest_dimension}
            label={@interest_dimension.label}
            max_level={@interest_dimension.max}
          />

          <.range_input
            field={@form[:skill_level]}
            dimension={@skill_dimension}
            label={@skill_dimension.label}
            max_level={@skill_dimension.max}
          />

          <.input
            field={@form[:description]}
            label="Description"
            type="textarea"
            class="text-sm w-full textarea h-36"
          />

          <.error :if={@error != nil}>{@error}</.error>

          <div class="flex items-center justify-between gap-2">
            <button
              :if={@mode == :edit and @tag_id}
              class="btn btn-soft btn-error"
              data-testid="member-tagging-delete"
              phx-click="tagging_remove"
              phx-value-tag_id={@tag_id}
              type="button"
            >
              <.icon name="hero-trash-mini" class="size-4" /> Delete
            </button>

            <.button class="btn btn-primary" data-testid="member-tagging-submit" type="submit">
              {@action_label}
            </.button>
          </div>
        </div>
      </Phoenix.Component.form>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :level, :integer, required: true
  attr :dimension, :map, required: true
  attr :testid, :string, required: true

  defp level_meter(assigns) do
    ~H"""
    <div class="min-w-0 flex items-center gap-1">
      <div
        class="tooltip"
        style={"--tt-bg: color-mix(#{@dimension.color} 0%, var(--color-base-300))"}
      >
        <div class="tooltip-content">
          <div class="font-bold text-xs">
            <span>{@label}:</span>
            <span>{"#{@level}/#{@dimension.max}"}</span>
          </div>
        </div>
        <progress
          class="progress w-full"
          data-testid={@testid}
          style={"color: #{@dimension.color};"}
          value={meter_value(@level, @dimension.max)}
          max="100"
        >
        </progress>
      </div>
    </div>
    """
  end

  attr :field, :any, required: true
  attr :label, :string, required: true
  attr :dimension, :map, required: true
  attr :max_level, :integer, required: true

  defp range_input(assigns) do
    ~H"""
    <div class="space-y-0">
      <div class="flex items-center justify-between gap-2">
        <label for={@field.id} class="text-sm font-medium">{@label}</label>
        <span class="badge badge-sm bg-base-100">{@field.value || "0"}</span>
      </div>

      <input
        id={@field.id}
        name={@field.name}
        type="range"
        min="0"
        max={@max_level}
        step="1"
        value={@field.value || "0"}
        class="range range-xs w-full"
        style={"color: #{@dimension.color};"}
      />
    </div>
    """
  end

  defp dimension(key), do: Dimensions.get!("group_user_relation", key)

  defp dimension_level(%Tagging{dimensions: dimensions}, key) when is_map(dimensions) do
    Map.get(dimensions, key)
  end

  defp dimension_level(_tagging, _key), do: nil

  defp meter_value(level, max_level)
       when is_integer(level) and is_integer(max_level) and max_level > 0 do
    trunc(level / max_level * 100)
  end

  defp meter_value(_level, _max_level), do: 0

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
