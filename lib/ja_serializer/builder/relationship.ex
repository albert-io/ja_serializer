defmodule JaSerializer.Builder.Relationship do
  @moduledoc false

  alias JaSerializer.Builder.Link
  alias JaSerializer.Builder.ResourceIdentifier

  defstruct [:name, :links, :data, :meta]

  def build(%{serializer: serializer, data: data, conn: conn, opts: opts} = context) do
    case opts[:relationships] do
      false -> []
      _ ->
        data
        |> serializer.relationships(conn)
        |> filter_relationships(serializer.type(context.data, context.conn), opts[:fields])
        |> Enum.map(&build(&1, context))
    end
  end

  def build({name, definition}, context) do
    definition = Map.put(definition, :name, name)
    %__MODULE__{name: name}
    |> add_links(definition, context)
    |> add_data(definition, context)
  end

  defp filter_relationships(relationships, type, fields) when is_map(fields) do
    if Map.has_key?(fields, type) do
      sanitized_fields =
        fields
        |> Map.get(type)
        |> safe_atom_list
        |> MapSet.new

      Enum.filter(relationships, fn {name, _definition} ->
        MapSet.member?(sanitized_fields, name)
      end)
    else
      relationships
    end
  end
  defp filter_relationships(relationships, _type, _fields), do: relationships

  defp add_links(relation, definition, context) do
    definition.links
      |> Enum.map(fn {key, path} -> Link.build(context, key, path) end)
      |> case do
        []   ->  relation
        links -> Map.put(relation, :links, links)
      end
  end

  defp add_data(relation, definition, context) do
    if should_have_identifiers?(definition, context) do
      Map.put(relation, :data, ResourceIdentifier.build(context, definition))
    else
      relation
    end
  end

  defp should_have_identifiers?(%{type: nil, serializer: nil}, _c),
    do: false
  defp should_have_identifiers?(%{type: _t, serializer: nil}, _c),
    do: true
  defp should_have_identifiers?(%{serializer: _s, identifiers: :always}, _c),
    do: true
  defp should_have_identifiers?(%{serializer: _s, identifiers: :when_included, name: name, include: true}, context) do
    case context[:opts][:include] do
      nil  -> true
      includes -> is_list(includes[name])
    end
  end
  defp should_have_identifiers?(%{serializer: _s, identifiers: :when_included, name: name}, context) do
    case context[:opts][:include] do
      nil  -> false
      includes -> is_list(includes[name])
    end
  end

  defp safe_atom_list(nil), do: []
  defp safe_atom_list(field_str) do
    field_str |> String.split(",") |> Enum.map(&String.to_existing_atom/1)
  end
end
