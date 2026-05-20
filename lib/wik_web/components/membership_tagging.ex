defmodule WikWeb.Components.MembershipTagging do
  use Phoenix.Component
  use WikWeb, :live_view
  import Phoenix.Component, except: [form: 1]

  alias Wik.Tags.Dimensions
  alias Wik.Tags.Tagging
  alias WikWeb.Components.User
  alias WikWeb.Cinder.Themes.DenseNoSortIcons
  alias WikWeb.Components.UI

  attr :membership, :map, required: true
  attr :query, :any, required: true
  attr :scope, :map, required: true

  def list(assigns) do
    assigns =
      assign(assigns,
        interest_dimension: dimension("interest"),
        skill_dimension: dimension("skill")
      )

    ~H"""
    <div
      :if={@query != nil}
      class="overflow-hidden"
      data-testid="member-taggings-table"
    >
      <Cinder.collection
        layout={:list}
        id="member-taggings"
        page_size={100}
        query={@query}
        scope={@scope}
        show_filters={true}
        sort_mode="exclusive"
        theme={DenseNoSortIcons}
      >
        <:col
          field="tag.name"
          label="Alphabetical"
          sort={[cycle: [:asc_nils_last]]}
        >
        </:col>
        <:col
          field="interest_level"
          label={@interest_dimension.label}
          sort={[cycle: [:desc_nils_last]]}
        >
        </:col>
        <:col
          field="skill_level"
          label={@skill_dimension.label}
          sort={[cycle: [:desc_nils_last]]}
        >
        </:col>

        <:item :let={tagging}>
          <% interest_level = dimension_level(tagging, "interest") %>
          <% skill_level = dimension_level(tagging, "skill") %>
          <.link
            patch={tagging_path(@scope, @membership, tagging)}
            data-testid={"member-tagging-open-#{tagging.tag_id}"}
            class="block px-4 py-3 rounded-lg bg-base-200 hover:bg-base-300 transition-colors cursor-pointer"
          >
            <div class="grid grid-cols-[1fr_6rem] gap-2 items-start">
              <div class="text-sm" data-testid={"member-tagging-row-#{tagging.tag_id}"}>
                <div data-testid={"member-tagging-name-#{tagging.tag_id}"}>
                  {tagging.tag.name}
                </div>
              </div>

              <div>
                <.level_meter
                  :if={interest_level}
                  dimension={@interest_dimension}
                  label={@interest_dimension.label}
                  level={interest_level}
                  testid={"member-tagging-interest-#{tagging.tag_id}"}
                />

                <.level_meter
                  :if={skill_level}
                  dimension={@skill_dimension}
                  label={@skill_dimension.label}
                  level={skill_level}
                  testid={"member-tagging-skill-#{tagging.tag_id}"}
                />
              </div>
            </div>
            <div
              :if={present?(tagging.description)}
              class="text-xs/4 opacity-60 pr-2 space-y-2 max-w-prose-lg mt-3"
              data-testid={"member-tagging-description-#{tagging.tag_id}"}
            >
              <.description_chunks description={tagging.description} />
            </div>
          </.link>
        </:item>
      </Cinder.collection>
    </div>
    """
  end

  attr :query, :any, required: true
  attr :scope, :map, required: true
  attr :tag, :map, required: true

  def list_for_tag(assigns) do
    assigns =
      assign(assigns,
        interest_dimension: dimension("interest"),
        skill_dimension: dimension("skill")
      )

    ~H"""
    <div
      :if={@query != nil}
      class="overflow-hidden"
      data-testid="tag-member-taggings-table"
    >
      <Cinder.collection
        layout={:list}
        id="tag-member-taggings"
        page_size={100}
        query={@query}
        scope={@scope}
        show_filters={true}
        sort_mode="exclusive"
        theme={DenseNoSortIcons}
      >
        <:col
          field="target_membership.username"
          label="Alphabetical"
          sort={[cycle: [:asc_nils_last]]}
        >
        </:col>
        <:col
          field="interest_level"
          label={@interest_dimension.label}
          sort={[cycle: [:desc_nils_last]]}
        >
        </:col>
        <:col
          field="skill_level"
          label={@skill_dimension.label}
          sort={[cycle: [:desc_nils_last]]}
        >
        </:col>

        <:item :let={tagging}>
          <% interest_level = dimension_level(tagging, "interest") %>
          <% skill_level = dimension_level(tagging, "skill") %>
          <.link
            navigate={member_tagging_path(@scope, tagging, @tag)}
            data-testid={"tag-member-tagging-open-#{tagging.id}"}
            class="block px-4 py-3 rounded-lg bg-base-200 hover:bg-base-300 transition-colors cursor-pointer"
          >
            <div class="grid grid-cols-[1fr_6rem] gap-2 items-start">
              <div class="min-w-0 text-sm" data-testid={"tag-member-tagging-row-#{tagging.id}"}>
                <div
                  class="flex items-center gap-3"
                  data-testid={"tag-member-tagging-member-#{tagging.id}"}
                >
                  <User.avatar
                    membership={tagging.target_membership}
                    size="sm"
                    tenant={@scope.tenant}
                  />
                  <div class="min-w-0">
                    <div class="truncate">{tagging.target_membership.username}</div>
                  </div>
                </div>
              </div>

              <div>
                <.level_meter
                  :if={interest_level}
                  dimension={@interest_dimension}
                  label={@interest_dimension.label}
                  level={interest_level}
                  testid={"tag-member-tagging-interest-#{tagging.id}"}
                />

                <.level_meter
                  :if={skill_level}
                  dimension={@skill_dimension}
                  label={@skill_dimension.label}
                  level={skill_level}
                  testid={"tag-member-tagging-skill-#{tagging.id}"}
                />
              </div>
            </div>
            <div
              :if={present?(tagging.description)}
              class="text-xs/4 opacity-60 pr-2 space-y-2 max-w-prose-lg mt-3"
              data-testid={"tag-member-tagging-description-#{tagging.id}"}
            >
              <.description_chunks description={tagging.description} />
            </div>
          </.link>
        </:item>
      </Cinder.collection>
    </div>
    """
  end

  attr :membership, :map, required: true
  attr :tagging, :map, required: true
  attr :tenant, :map, required: true
  attr :link?, :boolean, default: true

  def tagging_title(assigns) do
    ~H"""
    <div class="items-center gap-2 grid grid-cols-[1fr_auto_1fr]">
      <div class="flex justify-end">
        <User.avatar
          link?={@link?}
          membership={@membership}
          size="lg"
          tenant={@tenant}
          tooltip?
          tooltip_direction="left"
        />
      </div>

      <.icon name="hero-arrows-right-left-micro" class="opacity-50" />

      <UI.page_title class="text-lg flex justify-start">
        <.link
          :if={@link?}
          navigate={~p"/#{@tenant.slug}/tags/#{@tagging.tag.slug}"}
          class="underline decoration-dashed underline-offset-4 decoration-base-content/60 hover:decoration-solid"
        >
          {@tagging.tag.name}
        </.link>
        <span :if={!@link?}>{@tagging.tag.name}</span>
      </UI.page_title>
    </div>
    """
  end

  attr :editable?, :boolean, required: true
  attr :membership, :map, required: true
  attr :tagging, :map, required: true
  attr :tenant, :map, required: true

  def details(assigns) do
    assigns =
      assign(assigns,
        interest_dimension: dimension("interest"),
        interest_level: dimension_level(assigns.tagging, "interest"),
        skill_dimension: dimension("skill"),
        skill_level: dimension_level(assigns.tagging, "skill")
      )

    ~H"""
    <div class="space-y-6" data-testid="member-tagging-details">
      <.tagging_title
        membership={@membership}
        tagging={@tagging}
        tenant={@tenant}
        link?={true}
      />

      <div class="grid gap-3 sm:grid-cols-2">
        <div class="space-y-1 rounded-box bg-base-200 px-4 py-3">
          <div class="text-xs font-bold uppercase tracking-[0.14em] opacity-60">
            {@interest_dimension.label}
          </div>
          <div :if={@interest_level} class="space-y-2">
            <.level_meter
              dimension={@interest_dimension}
              label={@interest_dimension.label}
              level={@interest_level}
              testid={"member-tagging-interest-#{@tagging.tag_id}"}
            />
          </div>
          <div :if={is_nil(@interest_level)} class="text-sm opacity-50">
            No value
          </div>
        </div>

        <div class="space-y-1 rounded-box bg-base-200 px-4 py-3">
          <div class="text-xs font-bold uppercase tracking-[0.14em] opacity-60">
            {@skill_dimension.label}
          </div>
          <div :if={@skill_level} class="space-y-2">
            <.level_meter
              dimension={@skill_dimension}
              label={@skill_dimension.label}
              level={@skill_level}
              testid={"member-tagging-skill-#{@tagging.tag_id}"}
            />
          </div>
          <div :if={is_nil(@skill_level)} class="text-sm opacity-50">No value</div>
        </div>
      </div>

      <div :if={present?(@tagging.description)} class="space-y-2">
        <div class="text-xs font-bold uppercase tracking-[0.14em] opacity-60">Description</div>
        <div class="space-y-1 text-sm/6 opacity-80" data-testid="member-tagging-details-description">
          <.description_chunks description={@tagging.description} />
        </div>
      </div>

      <div :if={@editable?} class="flex justify-end">
        <UI.button_edit
          data-testid={"member-tagging-edit-#{@tagging.tag_id}"}
          phx-click="tagging_edit_start"
          phx-value-tag_id={@tagging.tag_id}
        />
      </div>
    </div>
    """
  end

  attr :action_label, :string, required: true
  attr :error, :string, default: nil
  attr :form, :any, required: true
  attr :membership, :map, required: true
  attr :mode, :atom, required: true
  attr :options, :list, required: true
  attr :tag, :map, default: nil
  attr :tenant, :map, required: true

  def form(assigns) do
    assigns =
      assign(assigns,
        interest_dimension: dimension("interest"),
        skill_dimension: dimension("skill"),
        tagging_title_tagging: if(assigns.tag, do: %{tag: assigns.tag}, else: nil)
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
            <.tagging_title
              :if={@tagging_title_tagging}
              membership={@membership}
              tagging={@tagging_title_tagging}
              tenant={@tenant}
              link?={false}
            />
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
              :if={@mode == :edit and @tag}
              class="btn btn-soft btn-error"
              data-testid="member-tagging-delete"
              phx-click="tagging_remove"
              phx-value-tag_id={@tag.id}
              type="button"
            >
              <.icon name="hero-trash-mini" class="size-4" /> Delete
            </button>

            <.button class="btn btn-accent btn-soft" data-testid="member-tagging-submit" type="submit">
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
        class="tooltip leading-none"
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
        <label for={@field.id} class="label font-bold">{@label}</label>
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

  attr :description, :string, required: true

  defp description_chunks(assigns) do
    assigns = assign(assigns, :chunks, split_description(assigns.description))

    ~H"""
    <div :for={chunk <- @chunks}>{chunk}</div>
    """
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp split_description(description) when is_binary(description) do
    description
    |> String.trim()
    |> String.split(~r/\n+/, trim: true)
  end

  defp tagging_path(scope, membership, tagging) do
    ~p"/#{scope.tenant.slug}/wiki/members/#{membership.username}/tag/#{tagging.tag.slug}"
  end

  defp member_tagging_path(scope, tagging, tag) do
    ~p"/#{scope.tenant.slug}/wiki/members/#{tagging.target_membership.username}/tag/#{tag.slug}"
  end
end
