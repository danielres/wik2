defmodule WikWeb.Components.Event.Panels.Participation do
  use WikWeb, :html

  alias Wik.Events.Dimensions
  alias WikWeb.Components.LevelMeter
  alias WikWeb.Components.User

  attr :current_membership, :map, default: nil
  attr :current_member_participation, :any, default: nil
  attr :participations, :list, default: []
  attr :source_id, :string, required: true
  attr :source_type, :string, required: true
  attr :testid_prefix, :string, default: "event"

  def render(assigns) do
    assigns = assign(assigns, :interest_dimension, interest_dimension())

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

      <div
        :for={participation <- @participations}
        data-testid={"#{@testid_prefix}-participation-#{participation.id}"}
        class={[
          "rounded-md bg-base-content/5 px-2 py-1"
        ]}
      >
        <div class={[
          "flex justify-between"
        ]}>
          <User.identity
            avatar_size="xs"
            class="text-xs opacity-70"
            membership={participation.membership}
          />

          <div class="flex gap-1 items-center">
            <LevelMeter.render
              :if={
                !@current_member_participation ||
                  participation.membership_id != @current_member_participation.membership_id
              }
              dimension={@interest_dimension}
              label="Interest"
              level={participation.interest}
              testid={"#{@testid_prefix}-participation-interest-#{participation.id}"}
              width_class="w-10"
              class="ml-auto mr-2"
            />

            <button
              :if={
                @current_member_participation &&
                  participation.membership_id == @current_member_participation.membership_id
              }
              type="button"
              class={["btn btn-ghost btn-xs hover:btn-soft rounded-full"]}
              data-testid={"#{@testid_prefix}-detail-interest-#{@source_id}"}
              phx-click="event_interest_start"
              phx-value-id={@source_id}
              phx-value-source_type={@source_type}
            >
              <.icon
                name="hero-pencil-micro"
                style={"color: #{@interest_dimension.color}"}
              />
              <LevelMeter.render
                dimension={@interest_dimension}
                label="Interest"
                level={participation.interest}
                testid={"#{@testid_prefix}-participation-interest-#{participation.id}"}
                width_class="w-10"
                class="ml-auto"
              />
            </button>
          </div>
        </div>
        <div :if={participation.extra_info not in [nil, ""]} class="opacity-70 text-xs ml-5">
          {participation.extra_info}
        </div>
      </div>
    </WikWeb.Components.Event.Panel.render>
    """
  end

  defp interest_dimension, do: Dimensions.get!("participation", "interest")
end
