defmodule Wik.Accounts.User.Senders.SendMagicLinkEmail do
  @moduledoc """
  Sends a magic link email
  """

  use AshAuthentication.Sender
  use WikWeb, :verified_routes

  import Swoosh.Email
  alias Wik.Mailer

  @impl true
  def send(user_or_email, token, _) do
    # if you get a user, its for a user that already exists.
    # if you get an email, then the user does not yet exist.

    email =
      case user_or_email do
        %{email: email} -> email
        email -> email
      end

    new()
    |> from({"Wik", contact_email()})
    |> reply_to(privacy_contact_email())
    |> to(to_string(email))
    |> subject("Your login link")
    |> html_body(body(token: token, email: email))
    |> Mailer.deliver!()
  end

  defp body(params) do
    # NOTE: You may have to change this to match your magic link acceptance URL.
    magic_link_url = magic_link_url(params[:token])

    """
    <p>Hello, #{params[:email]}! Click this link to sign in:</p>

    <p><a href="#{magic_link_url}">#{magic_link_url}</a></p>

    """
  end

  defp magic_link_url(token) do
    case System.get_env("DEV_HOST") do
      nil -> url(~p"/magic_link/#{token}")
      "" -> url(~p"/magic_link/#{token}")
      lan_host -> "http://#{lan_host}:#{endpoint_port()}/magic_link/#{token}"
    end
  end

  defp endpoint_port do
    WikWeb.Endpoint.config(:http) |> Keyword.fetch!(:port)
  end

  defp contact_email do
    Application.get_env(:wik, :contact_email, "noreply@example.com")
  end

  defp privacy_contact_email do
    Application.get_env(:wik, :privacy_contact_email, contact_email())
  end
end
