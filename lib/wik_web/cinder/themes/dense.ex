defmodule WikWeb.Cinder.Themes.Dense do
  use Cinder.Theme

  extends :daisy_ui

  set :controls_class, "p-0 mb-4"
  set :filter_container_class, "bg-base-200/50 rounded-md"
  set :filter_title_class, "font-bold"
  set :filter_header_class, "px-4 py-2"

  set :filter_label_class, "text-xs font-bold"

  set :filter_inputs_class,
      "p-4 pt-0 text grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-x-2 gap-y-2"

  set :filter_text_input_class, "input input-sm w-full"
  set :search_input_class, "input input-sm pl-10 w-full"
  set :table_class, "table bg-base-200/50"
  set :row_class, "hover:bg-base-300/40"

  set :th_class,
      "py-1 sm:py-2 px-2 sm:px-4 bg-base-300 [&:first-child]:rounded-tl-md [&:last-child]:rounded-tr-md text-xs uppercase tracking-wider"

  set :td_class, "py-1 sm:py-2 px-2 sm:px-4 align-top"
  set :loading_container_class, "hidden"
end
