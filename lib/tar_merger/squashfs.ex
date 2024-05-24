defmodule TarMerger.SquashFS do
  alias TarMerger.Entry

  @spec pseudofile([Entry.t()]) :: iolist()
  def pseudofile(entries) when is_list(entries) do
    Enum.map(entries, &pseudofile_line/1)
  end

  defp pseudofile_line(entry) do
    case entry.type do
      :block_device ->
        "#{entry.path} b #{octal(entry.mode)} #{entry.uid} #{entry.gid} #{entry.major_device} #{entry.minor_device}\n"

      :character_device ->
        "#{entry.path} c #{octal(entry.mode)} #{entry.uid} #{entry.gid} #{entry.major_device} #{entry.minor_device}\n"

      :directory ->
        "#{entry.path} d #{octal(entry.mode)} #{entry.uid} #{entry.gid}\n"

      :regular ->
        "#{entry.path} m #{octal(entry.mode)} #{entry.uid} #{entry.gid}\n"

      :symlink ->
        "#{entry.path} s #{octal(entry.mode)} #{entry.uid} #{entry.gid} #{entry.link}\n"
    end
  end

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
    File.mkdir!(output_path)
  end

  defp write_entry(_path, _entry), do: :ok

  @spec sort_file([Entry.t()]) :: [String.t()]
  def sort_file(entries) when is_list(entries) do
    sort_file_line(entries, -32768, [])
  end

  defp sort_file_line([], _counter, acc) do
    Enum.reverse(acc)
  end

  defp sort_file_line([entry | rest], counter, acc) do
    if entry.type == :regular do
      sort_file_line(rest, counter + 1, ["#{entry.path} #{counter}\n" | acc])
    else
      sort_file_line(rest, counter, acc)
    end
  end

  defp octal(num), do: Integer.to_string(num, 8)
end
