defmodule WikWeb.Docs.Pages.Updates do
  use WikWeb.Docs.Page

  def slug, do: "updates"
  def title, do: "Updates"

  def render(assigns) do
    ~H"""
    <h1>Updates</h1>

    <p>New features, improvements, and fixes added to Wik.</p>

    <div id="product-updates">
      <p :if={@updates == []} id="product-updates-empty">No updates yet.</p>

      <article
        :for={update <- @updates}
        id={"update-#{update.pr_number}"}
        class={[
          "not-prose",
          "border-base-300 border-t",
          "py-8 first:border-t-0 first:pt-2"
        ]}
      >
        <h2 class={["text-2xl", "font-semibold"]}>Update #{update.pr_number}</h2>
        <time
          class={["text-base-content/60", "text-sm"]}
          datetime={Date.to_iso8601(update.merged_on)}
        >
          {Calendar.strftime(update.merged_on, "%a, %b %-d %Y")}
        </time>

        <section :for={section <- update.sections} class="mt-6">
          <h3 class={["text-lg font-semibold", "capitalize"]}>
            {Phoenix.Naming.humanize(section.category)}
          </h3>
          <ul class={["mt-2 pl-6", "list-disc space-y-1"]}>
            <li :for={item <- section.items}>{item}</li>
          </ul>
        </section>

        <.link
          class={["link link-primary", "mt-6 inline-block"]}
          href={"https://github.com/danielres/wik2/pull/#{update.pr_number}"}
          id={"update-#{update.pr_number}-pull-request"}
        >
          View pull request on GitHub
        </.link>
      </article>
    </div>
    """
  end
end
