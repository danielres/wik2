defmodule WikWeb.Docs.Pages.Index do
  use WikWeb.Docs.Page

  def slug, do: "index"
  def title, do: "What is Wik?"

  def render(assigns) do
    # We don't only waste screen time because apps are addictive, but because our real-world social field is illegible.
    #
    # We don't know:
    #
    # - who is available
    # - what is happening
    # - what people want to do
    # - which ideas are alive
    # - where our group energy is
    # - what could become real

    ~MD"""
    #### Wik helps existing groups coordinate clearly

    - local scenes and neighbourhoods
    - friendship and support circles
    - teams, classes, communities, clubs, collectives, …


    <hr class="sm:max-w-xl"/>

    #### Most groups hold a quiet abundance

    - overlapping interests, useful knowledge, unfinished ideas
    - shared intentions, compatible availability, …

    <div class="max-w-xl text-sm text-balance">
      But much of it stays hidden inside scattered messages, private conversations, forgotten plans, and endless threads.
    </div>


    **Wik helps make that potential visible**

    <div class="max-w-xl text-sm text-balance">
      It gives groups a shared place to gather what matters, find what is possible, and turn “we should do this sometime” into real events, shared projects, and time together.
    </div>

    <hr class="sm:max-w-xl"/>

    #### Wik is built for clarity, not retention

    <div class="max-w-xl text-sm text-balance">
      Not another feed.
      <br />
      Not another place trying to capture your attention.
      <br />
      <br />
      A calmer tool for making shared possibilities visible, and turning screen time into more meaningful time together.
    </div>

    """HEEX
  end
end
