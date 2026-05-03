defmodule WikWeb.Cinder.Themes.Dense do
  use Cinder.Theme

  extends :daisy_ui

  set :filter_container_class, "bg-base-300 rounded-box "
  set :filter_title_class, "font-bold"
  set :filter_header_class, "p-4"

  set :filter_label_class, "text-xs font-bold"

  set :filter_inputs_class,
      "p-4 pt-0 text grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-x-2 gap-y-2"

  set :filter_text_input_class, "input input-sm w-full"
  set :search_input_class, "input input-sm pl-10"
  set :table_class, "table"
  set :th_class, "py-1 sm:py-2 px-2 sm:px-4"
  set :td_class, "py-1 sm:py-2 px-2 sm:px-4"
  set :loading_container_class, "hidden"
end
