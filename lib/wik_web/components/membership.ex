defmodule WikWeb.Components.Membership do
  use WikWeb, :html

  alias WikWeb.Components

  attr :form, :map, required: true
  attr :group, :map, required: true

  def steps(assigns) do
    ~H"""
    <Components.UI.steps id="membership" class="prose">
      <:step label="House rules">
        <h1>Wik house rules</h1>
        <Components.Content.terms />
      </:step>

      <:step label="Username">
        <h1>Welcome to <span class="xfont-bold">{@group.name}</span> !</h1>

        <%= if @group.description do %>
          <h3>Group description</h3>
          <div class="whitespace-pre-wrap bg-base-200 p-4 rounded">{@group.description}</div>
        <% end %>

        <h2>Your username</h2>
        <.form
          autocomplete="off"
          for={@form}
          id="membership-username-form"
          phx-change="membership_username_validate"
          phx-submit="membership_username_submit"
          class="space-y-4"
        >
          <p>How would you like to be called within this group?</p>
          <.input
            field={@form[:username]}
            placeholder="Username"
            type="text"
            autocomplete="off"
            data-slugify-pattern={Utils.Slugify.js_slugify_pattern()}
            phx-hook="SlugifyInput"
            class="input input-bordered w-full"
          />
        </.form>
      </:step>

      <:action step={2}>
        <button
          aria-label="Submit"
          class="btn btn-xs btn-circle btn-success"
          form="membership-username-form"
          title="Submit"
          type="submit"
        >
          <.icon name="hero-check-micro" />
        </button>
      </:action>
    </Components.UI.steps>
    """
  end
end
