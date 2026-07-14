defmodule WikWeb.Components.Event.Panels.Participation do
  use WikWeb, :html

  alias Wik.Events.Dimensions
  alias WikWeb.Components.LevelMeter
  alias WikWeb.Components.User

  attr :current_membership, :map, default: nil
  attr :current_member_participation, :any, default: nil
  attr :participations, :list, default: []
  attr :scope, :map, default: nil
  attr :source_id, :string, required: true
  attr :source_type, :string, required: true
  attr :testid_prefix, :string, default: "event"

  def render(assigns) do
    assigns =
      assigns
      |> assign(:interest_dimension, interest_dimension())
      |> assign(
        :sorted_participations,
        sort_participations(assigns.participations, assigns.current_member_participation)
      )

    ~H"""
    <WikWeb.Components.Event.Panel.render title="Participation">
      <div
        :if={@current_membership && !@current_member_participation}
        class={[
          "rounded-md bg-base-content/5 px-2 py-1",
          "mb-2"
        ]}
      >
        <div class={["flex justify-between"]}>
          <User.identity
            avatar_size="xs"
            class="text-xs opacity-70"
            membership={@current_membership}
          />
          <button
            type="button"
            class="btn btn-xs transition btn-neutral btn-soft"
            data-testid={"#{@testid_prefix}-detail-interest-#{@source_id}"}
            phx-click="event_interest_start"
            phx-value-id={@source_id}
            phx-value-source_type={@source_type}
            style={"color: #{@interest_dimension.color}"}
          >
            <span>Add</span>
            <.icon
              name="hero-plus-circle-micro"
              class="scale-80"
              style={"color: #{@interest_dimension.color}"}
            />
          </button>
        </div>
      </div>

      <p :if={!@current_membership} class="text-sm text-error">
        You need to be a member of this space to add interest.
      </p>

      <.participation_item
        :for={participation <- @sorted_participations}
        current?={current_participation?(participation, @current_member_participation)}
        interest_dimension={@interest_dimension}
        participation={participation}
        scope={@scope}
        source_id={@source_id}
        source_type={@source_type}
        testid_prefix={@testid_prefix}
      />
    </WikWeb.Components.Event.Panel.render>
    """
  end

  defp interest_dimension, do: Dimensions.get!("participation", "interest")

  defp sort_participations(participations, current_member_participation) do
    Enum.sort_by(participations, fn participation ->
      if current_participation?(participation, current_member_participation), do: 0, else: 1
    end)
  end

  attr :current?, :boolean, required: true
  attr :interest_dimension, :map, required: true
  attr :participation, :map, required: true
  attr :scope, :map, default: nil
  attr :source_id, :string, required: true
  attr :source_type, :string, required: true
  attr :testid_prefix, :string, required: true

  defp participation_item(assigns) do
    assigns =
      assign(
        assigns,
        :profile_path,
        profile_path(assigns.scope, assigns.participation.membership)
      )

    ~H"""
    <button
      :if={@current?}
      type="button"
      class={[participation_item_class()]}
      data-testid={"#{@testid_prefix}-participation-#{@participation.id}"}
      phx-click="event_interest_start"
      phx-value-id={@source_id}
      phx-value-source_type={@source_type}
    >
      <.participation_content
        current?={@current?}
        interest_dimension={@interest_dimension}
        participation={@participation}
        testid_prefix={@testid_prefix}
      />
    </button>

    <.link
      :if={!@current? and @profile_path}
      navigate={@profile_path}
      class={participation_item_class([])}
      data-testid={"#{@testid_prefix}-participation-#{@participation.id}"}
    >
      <.participation_content
        current?={@current?}
        interest_dimension={@interest_dimension}
        participation={@participation}
        testid_prefix={@testid_prefix}
      />
    </.link>

    <div
      :if={!@current? and is_nil(@profile_path)}
      class={participation_item_class()}
      data-testid={"#{@testid_prefix}-participation-#{@participation.id}"}
    >
      <.participation_content
        current?={@current?}
        interest_dimension={@interest_dimension}
        participation={@participation}
        testid_prefix={@testid_prefix}
      />
    </div>
    """
  end

  attr :current?, :boolean, required: true
  attr :interest_dimension, :map, required: true
  attr :participation, :map, required: true
  attr :testid_prefix, :string, required: true

  defp participation_content(assigns) do
    ~H"""
    <div class="flex justify-between min-h-6">
      <User.identity
        avatar_size="xs"
        class="text-xs opacity-70"
        membership={@participation.membership}
      />
      <div class="flex gap-1 items-center">
        <.icon
          :if={@current?}
          name="hero-pencil-micro"
          style={"color: #{@interest_dimension.color}"}
        />
        <LevelMeter.render
          dimension={@interest_dimension}
          label="Interest"
          level={@participation.interest}
          testid={"#{@testid_prefix}-participation-interest-#{@participation.id}"}
          width_class="w-20"
        />
      </div>
    </div>
    <div :if={@participation.extra_info not in [nil, ""]} class="opacity-70 text-xs ml-5">
      {@participation.extra_info}
    </div>
    """
  end

  defp current_participation?(_participation, nil), do: false

  defp current_participation?(participation, current_member_participation) do
    participation.membership_id == current_member_participation.membership_id
  end

  defp participation_item_class(extra \\ []) do
    [
      "opacity-80 hover:opacity-100 transition-opacity",
      "w-full rounded-md bg-base-content/5 px-2 py-1",
      "block",
      "cursor-pointer",
      extra
    ]
  end

  defp profile_path(%{tenant: %{slug: tenant_slug}}, %{username: username})
       when is_binary(username) and username != "" do
    ~p"/#{tenant_slug}/wiki/members/#{username}"
  end

  defp profile_path(_scope, _membership), do: nil
end
