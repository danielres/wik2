defmodule Wik.Updates do
  @moduledoc false

  alias Wik.Updates.Update

  @categories ~w(
    bug_fixes
    improvements
    new_features
    performance
    permissions
    reliability
  )

  @spec list_updates() :: {:ok, [Update.t()]} | {:error, term()}
  def list_updates do
    :wik
    |> Application.app_dir("priv/updates")
    |> list_updates()
  end

  @doc false
  @spec list_updates(Path.t()) :: {:ok, [Update.t()]} | {:error, term()}
  def list_updates(directory) do
    with {:ok, paths} <- list_update_paths(directory),
         {:ok, updates} <- load_updates(paths) do
      updates =
        Enum.sort_by(
          updates,
          &{Date.to_gregorian_days(&1.merged_on), &1.pr_number},
          :desc
        )

      {:ok, updates}
    end
  end

  defp list_update_paths(directory) do
    case File.ls(directory) do
      {:ok, filenames} ->
        paths =
          filenames
          |> Enum.filter(&(Path.extname(&1) == ".json"))
          |> Enum.sort()
          |> Enum.map(&Path.join(directory, &1))

        {:ok, paths}

      {:error, reason} ->
        {:error, {:updates_directory_unavailable, directory, reason}}
    end
  end

  defp load_updates(paths) do
    Enum.reduce_while(paths, {:ok, []}, fn path, {:ok, updates} ->
      case load_update(path) do
        {:ok, update} -> {:cont, {:ok, [update | updates]}}
        {:error, reason} -> {:halt, {:error, {:invalid_update, path, reason}}}
      end
    end)
  end

  defp load_update(path) do
    with {:ok, pr_number} <- pr_number_from_path(path),
         {:ok, contents} <- read_file(path),
         {:ok, data} <- decode_json(contents),
         {:ok, update} <- data_to_update(data, pr_number) do
      {:ok, update}
    end
  end

  defp pr_number_from_path(path) do
    filename = Path.basename(path, ".json")

    case Integer.parse(filename) do
      {pr_number, ""} when pr_number > 0 ->
        if Integer.to_string(pr_number) == filename,
          do: {:ok, pr_number},
          else: {:error, :invalid_filename}

      _invalid_filename ->
        {:error, :invalid_filename}
    end
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, contents} -> {:ok, contents}
      {:error, reason} -> {:error, {:file_unreadable, reason}}
    end
  end

  defp decode_json(contents) do
    case Jason.decode(contents) do
      {:ok, data} -> {:ok, data}
      {:error, error} -> {:error, {:invalid_json, Exception.message(error)}}
    end
  end

  defp data_to_update(
         %{"merged_on" => merged_on, "sections" => sections},
         pr_number
       )
       when is_binary(merged_on) do
    case Date.from_iso8601(merged_on) do
      {:ok, merged_on} ->
        with {:ok, sections} <- data_to_sections(sections) do
          {:ok,
           %Update{
             merged_on: merged_on,
             pr_number: pr_number,
             sections: sections
           }}
        end

      {:error, _reason} ->
        {:error, :invalid_merged_on}
    end
  end

  defp data_to_update(_data, _pr_number), do: {:error, :invalid_update_shape}

  defp data_to_sections(sections) when is_list(sections) and sections != [] do
    Enum.reduce_while(sections, {:ok, []}, fn section, {:ok, sections} ->
      case data_to_section(section) do
        {:ok, section} -> {:cont, {:ok, [section | sections]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, sections} -> {:ok, Enum.reverse(sections)}
      error -> error
    end
  end

  defp data_to_sections(_sections), do: {:error, :invalid_sections}

  defp data_to_section(%{"category" => category, "items" => items})
       when is_binary(category) and is_list(items) do
    cond do
      category not in @categories ->
        {:error, {:invalid_category, category}}

      items == [] or not Enum.all?(items, &(is_binary(&1) and String.trim(&1) != "")) ->
        {:error, :invalid_items}

      true ->
        {:ok, %{category: category, items: items}}
    end
  end

  defp data_to_section(_section), do: {:error, :invalid_section}
end
