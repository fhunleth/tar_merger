defmodule TarMerger.SquashFS do
  @moduledoc false
  import TarMerger.Util
  alias TarMerger.Entry

  @type options() :: [
          tmp_dir: Path.t(),
          mksquashfs_options: [String.t()],
          compressor: :gzip | :lzo | :lz4 | :zstd
        ]

  @spec mkfs_squashfs(Path.t(), [Entry.t()], options()) :: :ok | :error
  def mkfs_squashfs(squashfs_path, entries, options \\ []) when is_list(entries) do
    tmp_dir = Keyword.get_lazy(options, :tmp_dir, &System.tmp_dir!/0)
    extra_options = Keyword.get(options, :mksquashfs_options, [])

    pseudo_file_path = Path.join(tmp_dir, "pseudo-file")
    sort_file_path = Path.join(tmp_dir, "sort-file")
    squashfs_root = Path.join(tmp_dir, "rootfs")

    File.write!(pseudo_file_path, pseudo_file(entries))
    File.write!(sort_file_path, sort_file(entries))
    _ = File.rm_rf!(squashfs_root)
    File.mkdir!(squashfs_root)
    write_input_tree(squashfs_root, entries)

    cmd(
      "mksquashfs",
      [
        squashfs_root,
        squashfs_path,
        "-pf",
        pseudo_file_path,
        "-sort",
        sort_file_path,
        "-noappend",
        "-no-recovery",
        "-no-progress"
      ] ++ mksquashfs_options(options) ++ extra_options
    )
  after
  end

  defp mksquashfs_options(options) do
    [
      compressor_options(options)
    ]
    |> List.flatten()
  end

  defp compressor_options(options) do
    case Keyword.fetch(options, :compressor) do
      {:ok, :gzip} -> ["-comp", "gzip"]
      {:ok, :lzo} -> ["-comp", "lzo"]
      {:ok, :lz4} -> ["-comp", "lz4"]
      {:ok, :zstd} -> ["-comp", "zstd"]
      {:ok, other} -> raise ArgumentError, "Don't know #{inspect(other)} compressor"
      :error -> ["-comp", "gzip"]
    end
  end

  @spec pseudo_file([Entry.t()]) :: iolist()
  def pseudo_file(entries) when is_list(entries) do
    Enum.map(entries, &pseudo_file_line/1)
  end

  defp pseudo_file_line(entry) do
    path = remove_tar_dot(entry.path)

    case entry.type do
      :block_device ->
        "#{path} b #{octal(entry.mode)} #{entry.uid} #{entry.gid} #{entry.major_device} #{entry.minor_device}\n"

      :character_device ->
        "#{path} c #{octal(entry.mode)} #{entry.uid} #{entry.gid} #{entry.major_device} #{entry.minor_device}\n"

      :directory ->
        if path != "/" do
          "#{path} m #{octal(entry.mode)} #{entry.uid} #{entry.gid}\n"
        else
          # mksquashfs gives a warning if you don't skip this.
          ""
        end

      :regular ->
        "#{path} m #{octal(entry.mode)} #{entry.uid} #{entry.gid}\n"

      :symlink ->
        "#{path} s #{octal(entry.mode)} #{entry.uid} #{entry.gid} #{entry.link}\n"
    end
  end

  defp remove_tar_dot("." <> path), do: path

  @spec write_input_tree(Path.t(), [Entry.t()]) :: :ok
  def write_input_tree(path, entries) when is_list(entries) do
    Enum.each(entries, &write_entry(path, &1))
  end

  defp write_entry(path, %{type: :regular, contents: {filename, offset}} = entry) do
    File.open(filename, [:read], fn f ->
      {:ok, data} = :file.pread(f, offset, entry.size)

      output_path = Path.join(path, entry.path)
      File.write(output_path, data)
    end)
  end

  defp write_entry(path, %{type: :directory} = entry) do
    output_path = Path.join(path, entry.path)
    File.mkdir_p!(output_path)
  end

  defp write_entry(_path, _entry), do: :ok

  @spec sort_file([Entry.t()]) :: [String.t()]
  def sort_file(entries) when is_list(entries) do
    sort_file_line(entries, -32768, [])
  end

  defp sort_file_line([], _counter, acc) do
    Enum.reverse(acc)
  end

  defp sort_file_line([%{type: :regular, contents: {path, _offset}} | rest], counter, acc) do
    sort_file_line(rest, counter + 1, ["#{path} #{counter}\n" | acc])
  end

  defp sort_file_line([_entry | rest], counter, acc) do
    sort_file_line(rest, counter, acc)
  end

  defp octal(num), do: Integer.to_string(num, 8)
end
