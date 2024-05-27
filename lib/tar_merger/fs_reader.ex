defmodule TarMerger.FSReader do
  @moduledoc false
  alias TarMerger.Entry

  @spec scan_directory(Path.t(), Path.t()) :: [Entry.t()]
  def scan_directory(path, root \\ "/") do
    prefix = normalize_dir(path)
    root = normalize_dir(root)

    scan_directory(ls!(path), prefix, root, [])
  end

  defp scan_directory([], _prefix, _root, acc) do
    Enum.reverse(acc)
  end

  defp scan_directory([path | rest], prefix, root, acc) do
    {stat, new_rest} =
      case File.lstat!(path) do
        %{type: :directory} = stat ->
          {stat, rest ++ ls!(path)}

        stat ->
          {stat, rest}
      end

    entry = to_entry(path, prefix, root, stat)
    scan_directory(new_rest, prefix, root, [entry | acc])
  end

  defp ls!(path) do
    File.ls!(path) |> Enum.map(&Path.join(path, &1))
  end

  defp normalize_dir(path) do
    # Tarball directories always end with /'s
    if String.ends_with?(path, "/") do
      path
    else
      path <> "/"
    end
  end

  defp target_path(original, prefix, root) do
    String.replace(original, prefix, root)
  end

  defp to_entry(path, prefix, root, %File.Stat{type: :regular} = stat) do
    Entry.regular(target_path(path, prefix, root),
      contents: {Path.absname(path), 0},
      mode: stat.mode,
      size: stat.size
    )
  end

  defp to_entry(path, prefix, root, %File.Stat{type: :directory} = stat) do
    Entry.directory(target_path(path, prefix, root), mode: stat.mode)
  end

  defp to_entry(path, prefix, root, %File.Stat{type: :symlink} = stat) do
    Entry.symlink(target_path(path, prefix, root),
      mode: stat.mode,
      link: File.read_link!(path)
    )
  end
end
