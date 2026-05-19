defmodule WikWeb.MemberProfileLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias Utils.Log
  alias Wik.Accounts
  alias Wik.Tags
  alias Wik.Tags.Dimensions
  alias Wik.Tags.Tag
  alias Wik.Tags.Tagging
  alias WikWeb.Components.Modal
  alias WikWeb.Components.UI

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @max_level 10

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       available_tags: [],
       editable?: false,
       membership: nil,
       subscribed_target_id: nil,
       taggings: [],
       tagging_count: 0,
       tagging_modal: new_tagging_modal()
     )}
  end

  @impl true
  def handle_params(%{"username" => username}, url, socket) do
    socket =
      case if(socket.assigns.membership && socket.assigns.membership.username == username,
             do: {:ok, socket},
             else: refresh_profile(socket, username)
           ) do
        {:ok, socket} ->
          socket

        {:error, :not_found} ->
          socket
          |> put_flash(:error, "Member not found")
          |> push_navigate(to: ~p"/#{socket.assigns.current_scope.tenant.slug}/members")

        {:error, error} ->
          Log.scoped_error(
            socket.assigns.current_scope,
            error,
            "member tagging profile load failed"
          )

          socket
          |> put_flash(:error, "Couldn't load member profile")
          |> push_navigate(to: ~p"/#{socket.assigns.current_scope.tenant.slug}/members")
      end

    {:noreply, WikWeb.Presence.track_in_liveview(socket, url)}
  end

  @impl true
  def render(assigns) do
    interest_dimension = dimension("interest")
    skill_dimension = dimension("skill")

    assigns =
      assign(assigns,
        interest_dimension: interest_dimension,
        skill_dimension: skill_dimension,
        tagging_form_action: if(assigns.tagging_modal.mode == :edit, do: "Update", else: "Save"),
        tagging_form_open?: not is_nil(assigns.tagging_modal.form)
      )

    ~H"""
    <Layouts.app
      context={@context}
      flash={@flash}
      tenant_context={@tenant_context}
      scope={@current_scope}
    >
      <Layouts.group presences={@presences} scope={@current_scope} view="members">
        <div :if={@membership} class="space-y-4" data-testid="member-profile-page">
          <UI.page_title>
            <span class="flex flex-wrap items-center gap-2 font-[400] opacity-70">
              <.link
                navigate={~p"/#{@current_scope.tenant.slug}/members"}
                class="leading-none opacity-50 hover:opacity-100"
              >
                Members
              </.link>
              <.icon name="hero-chevron-right-mini" class="opacity-50" />
              {@membership.username}
            </span>
          </UI.page_title>

          <section class="flex items-center justify-start gap-4">
            <WikWeb.Components.User.avatar
              membership={@membership}
              size="xl"
              tenant={@current_scope.tenant}
              tooltip?
            />

            <span class="badge badge-sm bg-base-300 ml-auto">
              {@membership.type |> Atom.to_string() |> String.capitalize()}
            </span>
          </section>

          <section class="space-y-3">
            <div class="flex justify-end">
              <button
                :if={@editable?}
                class="btn btn-sm btn-soft btn-accent btn-circle"
                data-testid="member-tagging-add"
                phx-click="tagging_create_start"
                type="button"
              >
                <.icon name="hero-plus-mini" class="size-4" />
              </button>
            </div>

            <div
              :if={@tagging_count == 0}
              class="rounded-box border border-dashed border-base-300 bg-base-200/40 px-4 py-6 text-sm opacity-60"
              data-testid="member-tagging-empty"
            >
              No taggings yet.
            </div>

            <div
              :if={@tagging_count > 0}
              class="overflow-hidden rounded border border-base-300 bg-base-content/3"
              data-testid="member-taggings-table"
            >
              <table class={[
                "table",
                "[&_td]:align-top",
                "[&_th]:text-xs [&_th]:uppercase [&_th]:tracking-wider"
              ]}>
                <thead>
                  <tr class="bg-base-200">
                    <th>Tag</th>

                    <th class="w-32">
                      <div
                        class="flex items-center gap-1"
                        style={"--dimension-color: #{@interest_dimension.color};"}
                      >
                        {@interest_dimension.label}
                      </div>
                    </th>

                    <th class="w-32">
                      <div
                        class="flex items-center gap-1"
                        style={"--dimension-color: #{@skill_dimension.color};"}
                      >
                        {@skill_dimension.label}
                      </div>
                    </th>

                    <th></th>
                  </tr>
                </thead>

                <tbody>
                  <tr
                    :for={tagging <- @taggings}
                    class="hover border-b-1 border-base-300 [&:last-child]:border-0"
                  >
                    <td>
                      <div
                        class="min-w-0 font-medium"
                        data-testid={"member-tagging-row-#{tagging.tag_id}"}
                      >
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
                    </td>

                    <td>
                      <.level_meter
                        :if={dimension_level(tagging, "interest")}
                        dimension={@interest_dimension}
                        label={@interest_dimension.label}
                        level={dimension_level(tagging, "interest")}
                        testid={"member-tagging-interest-#{tagging.tag_id}"}
                      />
                    </td>

                    <td>
                      <.level_meter
                        :if={dimension_level(tagging, "skill")}
                        dimension={@skill_dimension}
                        label={@skill_dimension.label}
                        level={dimension_level(tagging, "skill")}
                        testid={"member-tagging-skill-#{tagging.tag_id}"}
                      />
                    </td>

                    <td>
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
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>
        </div>

        <Modal.render
          cancel="tagging_form_cancel"
          cancel_testid="member-tagging-cancel"
          open?={@tagging_form_open?}
          testid="member-tagging-dialog"
        >
          <.tagging_form
            :if={@tagging_form_open?}
            action_label={@tagging_form_action}
            error={@tagging_modal.error}
            form={@tagging_modal.form}
            tag_id={@tagging_modal.tag_id}
            mode={@tagging_modal.mode}
            options={@available_tags}
            tag_name={@tagging_modal.tag_name}
            membership={@membership}
            tenant={@current_scope.tenant}
          />
        </Modal.render>
      </Layouts.group>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :level, :integer, required: true
  attr :dimension, :map, required: true
  attr :testid, :string, required: true

  defp level_meter(assigns) do
    ~H"""
    <div class="min-w-0 flex items-center gap-1">
      <div class="tooltip" style={"--tt-bg: color-mix(#{@dimension.color} 0%, var(--color-base-300))"}>
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
          value={trunc(@level * 10)}
          max="100"
        >
        </progress>
      </div>
    </div>
    """
  end

  attr :action_label, :string, required: true
  attr :error, :string, default: nil
  attr :form, :any, required: true
  attr :mode, :atom, required: true
  attr :options, :list, required: true
  attr :tag_id, :string, default: nil
  attr :tag_name, :string, default: nil
  attr :membership, :map, required: true
  attr :tenant, :map, required: true

  defp tagging_form(assigns) do
    ~H"""
    <div data-testid="member-tagging-form">
      <.form
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
            dimension={dimension("interest")}
            label={dimension("interest").label}
            max_level={dimension("interest").max}
          />

          <.range_input
            field={@form[:skill_level]}
            dimension={dimension("skill")}
            label={dimension("skill").label}
            max_level={dimension("skill").max}
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
      </.form>
    </div>
    """
  end

  attr :field, :any, required: true
  attr :label, :string, required: true
  attr :dimension, :map, required: true
  attr :max_level, :integer, default: @max_level

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

  @impl true
  def handle_event("tagging_create_start", _params, socket) do
    {:noreply,
     assign(socket, :tagging_modal, new_tagging_modal(:create, form: init_tagging_form(nil)))}
  end

  def handle_event("tagging_edit_start", %{"tag_id" => tag_id}, socket) do
    tagging = Enum.find(socket.assigns.taggings, &(&1.tag_id == tag_id))

    {:noreply,
     assign(
       socket,
       :tagging_modal,
       new_tagging_modal(:edit,
         form: init_tagging_form(tagging),
         tag_id: tag_id,
         tag_name: tagging && tagging.tag && tagging.tag.name
       )
     )}
  end

  def handle_event("tagging_form_cancel", _params, socket) do
    {:noreply, close_tagging_form(socket)}
  end

  def handle_event("tagging_validate", %{"form" => params}, socket) do
    {:noreply,
     update(socket, :tagging_modal, fn modal ->
       %{modal | form: to_form(normalize_tagging_form(params), as: :form), error: nil}
     end)}
  end

  def handle_event("tagging_submit", %{"form" => params}, socket) do
    scope = socket.assigns.current_scope
    membership = socket.assigns.membership

    socket =
      case parse_tagging_params(params) do
        {:ok, tagging_params} ->
          case save_tagging_entry(
                 membership,
                 tagging_params.tag_id,
                 tagging_params,
                 scope
               ) do
            :ok ->
              socket
              |> close_tagging_form()
              |> try_reload_profile()

            {:error, error} ->
              Log.scoped_error(scope, error, "membership tagging submit failed")

              assign_tagging_form_error(socket, params, "Couldn't save that tagging.")
          end

        {:error, message} ->
          assign_tagging_form_error(socket, params, message)
      end

    {:noreply, socket}
  end

  def handle_event("tagging_remove", %{"tag_id" => tag_id}, socket) do
    scope = socket.assigns.current_scope
    membership = socket.assigns.membership

    socket =
      case remove_tagging_entry(membership, tag_id, scope) do
        :ok ->
          socket
          |> close_tagging_form()
          |> try_reload_profile()

        {:error, error} ->
          Log.scoped_error(scope, error, "membership tagging remove failed")
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(%{topic: topic}, socket) do
    group_id = socket.assigns.current_scope.tenant.id
    membership_id = socket.assigns.membership && socket.assigns.membership.id

    watched_topics =
      [Tag.group_pub_sub_topic(group_id)] ++
        if membership_id,
          do: [Tagging.target_pub_sub_topic("group_user_relation", membership_id)],
          else: []

    if topic in watched_topics and socket.assigns.membership do
      {:noreply, try_reload_profile(socket)}
    else
      {:noreply, socket}
    end
  end

  defp refresh_profile(socket, username) do
    scope = socket.assigns.current_scope

    case Accounts.get_membership_by_username(scope.tenant, username) do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, membership} ->
        with {:ok, taggings} <- Tags.list_membership_taggings(membership, scope: scope),
             {:ok, available_tags} <- Tags.list_group_tags(scope) do
          if connected?(socket) and socket.assigns.subscribed_target_id != membership.id do
            :ok = WikWeb.Endpoint.subscribe(Tag.group_pub_sub_topic(scope.tenant.id))

            :ok =
              WikWeb.Endpoint.subscribe(
                Tagging.target_pub_sub_topic("group_user_relation", membership.id)
              )
          end

          {:ok, assign_profile_state(socket, membership, taggings, available_tags)}
        else
          {:error, error} -> {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp try_reload_profile(socket) do
    case refresh_profile(socket, socket.assigns.membership.username) do
      {:ok, socket} -> socket
      {:error, _error} -> socket
    end
  end

  defp assign_profile_state(socket, membership, taggings, available_tags) do
    current_membership =
      socket.assigns.tenant_context && socket.assigns.tenant_context.current_membership

    profile_state = profile_state(membership, taggings, current_membership)

    socket
    |> assign(:available_tags, available_tags)
    |> assign(:membership, membership)
    |> assign(:taggings, sort_membership_taggings(taggings))
    |> assign(profile_state)
  end

  defp init_tagging_form(nil) do
    to_form(
      %{"tag_id" => "", "interest_level" => "0", "skill_level" => "0", "description" => ""},
      as: :form
    )
  end

  defp init_tagging_form(%Tagging{} = tagging) do
    to_form(
      %{
        "tag_id" => tagging.tag_id,
        "interest_level" => to_string(dimension_level(tagging, "interest") || 0),
        "skill_level" => to_string(dimension_level(tagging, "skill") || 0),
        "description" => tagging.description || ""
      },
      as: :form
    )
  end

  defp close_tagging_form(socket) do
    assign(socket, :tagging_modal, new_tagging_modal())
  end

  defp normalize_tagging_form(params) do
    %{
      "tag_id" => Map.get(params, "tag_id", ""),
      "interest_level" => Map.get(params, "interest_level", "0"),
      "skill_level" => Map.get(params, "skill_level", "0"),
      "description" => Map.get(params, "description", "")
    }
  end

  defp parse_tagging_params(params) do
    normalized = normalize_tagging_form(params)

    with tag_id when is_binary(tag_id) and tag_id != "" <- normalized["tag_id"],
         {interest_level, ""} <- Integer.parse(normalized["interest_level"]),
         {skill_level, ""} <- Integer.parse(normalized["skill_level"]),
         true <- interest_level in 0..@max_level,
         true <- skill_level in 0..@max_level do
      {:ok,
       %{
         description: normalized["description"],
         interest_level: interest_level,
         skill_level: skill_level,
         tag_id: tag_id
       }}
    else
      _ -> {:error, "Select a tag and set both levels between 0 and #{@max_level}."}
    end
  end

  defp save_tagging_entry(membership, tag_id, tagging_params, scope) do
    attrs = %{
      description: tagging_params.description,
      dimensions: %{
        "interest" => tagging_params.interest_level,
        "skill" => tagging_params.skill_level
      }
    }

    if empty_dimensions?(attrs.dimensions) do
      remove_tagging_entry(membership, tag_id, scope)
    else
      case Tags.upsert_membership_tagging(membership, tag_id, attrs, scope: scope) do
        {:ok, _tagging} -> :ok
        {:error, error} -> {:error, error}
      end
    end
  end

  defp remove_tagging_entry(membership, tag_id, scope) do
    case Tags.remove_membership_tagging(membership, tag_id, scope: scope) do
      {:ok, _tagging} -> :ok
      {:error, :not_found} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp assign_tagging_form_error(socket, params, message) do
    update(socket, :tagging_modal, fn modal ->
      %{modal | form: to_form(normalize_tagging_form(params), as: :form), error: message}
    end)
  end

  defp profile_state(membership, taggings, current_membership) do
    %{
      editable?: current_membership && current_membership.id == membership.id,
      subscribed_target_id: membership.id,
      tagging_count: length(taggings)
    }
  end

  defp new_tagging_modal(mode \\ nil, attrs \\ []) do
    %{
      error: Keyword.get(attrs, :error),
      form: Keyword.get(attrs, :form),
      mode: mode,
      tag_id: Keyword.get(attrs, :tag_id),
      tag_name: Keyword.get(attrs, :tag_name)
    }
  end

  defp dimension_level(%Tagging{dimensions: dimensions}, key) when is_map(dimensions) do
    Map.get(dimensions, key)
  end

  defp dimension_level(_tagging, _key), do: nil

  defp empty_dimensions?(dimensions) do
    dimensions
    |> Enum.reject(fn {_key, value} -> value == 0 end)
    |> Enum.empty?()
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp sort_membership_taggings(taggings) do
    Enum.sort_by(taggings, fn tagging ->
      {
        -(dimension_level(tagging, "interest") || 0),
        -(dimension_level(tagging, "skill") || 0),
        tagging.tag && String.downcase(tagging.tag.name || "")
      }
    end)
  end

  defp dimension(key), do: Dimensions.get!("group_user_relation", key)
end
