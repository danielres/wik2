defmodule Wik.Events.ExternalCalendarTopicRule.Validations.MatchFields do
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    title? = Ash.Changeset.get_attribute(changeset, :match_title)
    description? = Ash.Changeset.get_attribute(changeset, :match_description)

    if title? or description? do
      :ok
    else
      {:error,
       fields: [:match_title, :match_description], message: "at least one match field is required"}
    end
  end
end
