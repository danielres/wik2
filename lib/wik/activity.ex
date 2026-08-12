defmodule Wik.Activity do
  use Ash.Domain,
    otp_app: :wik,
    extensions: [AshAdmin.Domain, AshPhoenix]

  alias Wik.Activity.Entry

  require Ash.Query

  @categories [:wiki, :topics, :events, :members, :other]

  admin do
    show? true
  end

  resources do
    resource Entry
  end

  def categories, do: @categories

  def entries_query(category \\ :all)

  def entries_query(:all) do
    Entry
    |> Ash.Query.sort(occurred_at: :desc, id: :desc)
  end

  def entries_query(category) when category in @categories do
    Entry
    |> Ash.Query.filter(category == ^category)
    |> Ash.Query.sort(occurred_at: :desc, id: :desc)
  end

  def subscribe(space_id) when is_binary(space_id) do
    WikWeb.Endpoint.subscribe(Entry.space_pub_sub_topic(space_id))
  end
end
