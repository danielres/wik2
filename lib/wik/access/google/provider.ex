defmodule Wik.Access.Google.Provider do
  alias Assent.Strategy.Google, as: AssentGoogle

  def authorize_url(redirect_uri) when is_binary(redirect_uri) do
    redirect_uri
    |> config()
    |> AssentGoogle.authorize_url()
  end

  def callback(params, session_params, redirect_uri)
      when is_map(params) and is_map(session_params) and is_binary(redirect_uri) do
    redirect_uri
    |> config()
    |> Keyword.put(:session_params, session_params)
    |> AssentGoogle.callback(params)
  end

  def verified_email?(%{"email_verified" => true}), do: true
  def verified_email?(%{"email_verified" => "true"}), do: true
  def verified_email?(_user), do: false

  defp config(redirect_uri) do
    [
      client_id: System.fetch_env!("GOOGLE_CLIENT_ID"),
      client_secret: System.fetch_env!("GOOGLE_CLIENT_SECRET"),
      redirect_uri: redirect_uri
    ]
  end
end
