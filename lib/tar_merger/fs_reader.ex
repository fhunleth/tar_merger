defmodule TarMerger.FSReader do
  alias TarMerger.Entry

  def scan_directory(path) do
    prefix = normalize_dir(path)

    scan_directory(ls!(path), prefix, [])
  end

  defp scan_directory([], _prefix, acc) do
    Enum.reverse(acc)
  end

  defp scan_directory([path | rest], prefix, acc) do
    {stat, new_rest} =
      case File.lstat!(path) do
        %{type: :directory} = stat ->
          {stat, rest ++ ls!(path)}

        stat ->
          {stat, rest}
      end

    entry = to_entry(path, prefix, stat)
    scan_directory(new_rest, prefix, [entry | acc])
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

  defp trim_prefix(original, prefix) do
    prefix_size = byte_size(prefix)

    case original do
      <<^prefix::binary-size(prefix_size), rest::binary>> -> rest
      _ -> original
    end
  end

  defp to_entry(path, prefix, %File.Stat{type: :regular} = stat) do
    Entry.regular(trim_prefix(path, prefix),
      contents: {Path.absname(path), 0},
      mode: stat.mode,
      size: stat.size
    )
  end

  defp to_entry(path, prefix, %File.Stat{type: :directory} = stat) do
    Entry.directory(trim_prefix(path, prefix), mode: stat.mode)
  end

  defp to_entry(path, prefix, %File.Stat{type: :symlink} = stat) do
    Entry.symlink(trim_prefix(path, prefix),
      mode: stat.mode,
      link: File.read_link!(path)
    )
  end

  defp to_entry(path, prefix, %File.Stat{type: :device} = stat) do
    Entry.device(trim_prefix(path, prefix),
      mode: stat.mode,
      major_device: stat.major_device,
      minor_device: stat.minor_device
    )
  end
end
