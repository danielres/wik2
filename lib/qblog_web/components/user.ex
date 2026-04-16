defmodule QblogWeb.Components.User do
  use QblogWeb, :html

  attr :user, :map, required: true
  attr :href, :string, default: ""

  def avatar(assigns) do
    ~H"""
    <div class="avatar avatar-placeholder">
      <div class="bg-neutral text-neutral-content w-8 rounded-full text-xs ">
        <%= if @href != "" do %>
          <.link navigate={@href} class="opacity-80 hover:opacity-100 transition">
            {initials(@user)}
          </.link>
        <% else %>
          {initials(@user)}
        <% end %>
      </div>
    </div>
    """
  end

  defp initials(user) do
    user
    |> to_string()
    |> String.slice(0, 2)
    |> String.upcase()
  end
end
