defmodule Wik.Library.Provisioning do
  alias Wik.Library.EntryType
  alias Wik.Library.Field
  alias WikWeb.LibraryLive.Schema

  def ensure_default_types(scope) do
    case Wik.Library.list_entry_types(scope: scope) do
      {:ok, types} -> create_missing_default_types(types, scope)
      {:error, error} -> {:error, error}
    end
  end

  defp create_missing_default_types(types, scope) do
    existing_slugs = MapSet.new(types, & &1.slug)

    Schema.built_in_templates()
    |> Enum.reject(&(&1.id == "custom"))
    |> Enum.reject(&MapSet.member?(existing_slugs, &1.id))
    |> Enum.reduce_while(:ok, fn template, :ok ->
      case create_type(template, scope) do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp create_type(template, scope) do
    attrs = %{
      description: template.description,
      entry_creation_permission: :members,
      name: template.name,
      slug: template.id
    }

    case Ash.create(EntryType, attrs,
           action: :create,
           actor: scope.actor,
           authorize?: false,
           tenant: scope.tenant
         ) do
      {:ok, type} -> create_fields(type, template.fields, scope)
      {:error, error} -> {:error, error}
    end
  end

  defp create_fields(type, fields, scope) do
    fields
    |> Enum.with_index(1)
    |> Enum.reduce_while(:ok, fn {field, index}, :ok ->
      attrs = %{
        key: field.key,
        label: field.label,
        options: field.options,
        order_key: String.pad_leading(Integer.to_string(index), 6, "0"),
        required?: field.required?,
        type: field.type,
        type_id: type.id
      }

      case Ash.create(Field, attrs,
             action: :create,
             actor: scope.actor,
             authorize?: false,
             tenant: scope.tenant
           ) do
        {:ok, _field} -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end
end
