defmodule TarMerger.TarReader do
  @moduledoc false
  # See https://pubs.opengroup.org/onlinepubs/9699919799/

  alias TarMerger.Entry

  @record_size 512

  def read_tar(tar_path) do
    File.open!(tar_path, [:read], fn file ->
      parse_tar_entries(file, tar_path, 0, [])
    end)
  end

  defp parse_tar_entries(file, tar_path, next_offset, acc) do
    case IO.binread(file, @record_size) do
      {:error, reason} ->
        {:error, reason}

      <<0::integer-size(4096)>> ->
        Enum.reverse(acc)

      header_block when byte_size(header_block) == @record_size ->
        {entry, next_offset} =
          read_entry(file, tar_path, header_block, next_offset + @record_size)

        parse_tar_entries(file, tar_path, next_offset, [entry | acc])

      _ ->
        acc
    end
  end

  defp round_to_record(value), do: div(value + @record_size - 1, @record_size) * @record_size

  defp read_entry(file, tar_path, header_block, next_offset) do
    case parse_header(tar_path, header_block, next_offset) do
      %{type: :pax_header, size: pax_size} ->
        rounded_pax_size = round_to_record(pax_size)
        pax_header = IO.binread(file, rounded_pax_size)
        real_header_block = IO.binread(file, @record_size)
        next_offset = next_offset + rounded_pax_size + @record_size

        entry =
          parse_header(tar_path, real_header_block, next_offset)
          |> update_entry_from_pax(pax_header)

        next_offset = next_offset + round_to_record(entry.size)
        :file.position(file, next_offset)
        {entry, next_offset}

      %{size: size} = entry ->
        # Skip over the file contents.
        next_offset = next_offset + round_to_record(size)
        :file.position(file, next_offset)
        {entry, next_offset}
    end
  end

  defp update_entry_from_pax(entry, pax_header) do
    pax_header
    |> trim_null
    |> String.split("\n", trim: true)
    |> Enum.reduce(entry, &parse_pax_line/2)
  end

  @pax_line ~r/^(\d+)\s+(\w+)=(\w+)$/
  defp parse_pax_line(line, entry) do
    case Regex.run(@pax_line, line) do
      [_, _length, key, value] ->
        if key not in ["atime", "ctime"], do: IO.inspect(line)
        pax_update_entry(entry, key, value)

      _ ->
        entry
    end
  end

  defp pax_update_entry(entry, "linkpath", value), do: %{entry | link: value}
  defp pax_update_entry(entry, "path", value), do: %{entry | path: value}
  defp pax_update_entry(entry, _key, _value), do: entry

  # struct posix_header
  # {                              /* byte offset */
  #   char name[100];               /*   0 */
  #   char mode[8];                 /* 100 */
  #   char uid[8];                  /* 108 */
  #   char gid[8];                  /* 116 */
  #   char size[12];                /* 124 */
  #   char mtime[12];               /* 136 */
  #   char chksum[8];               /* 148 */
  #   char typeflag;                /* 156 */
  #   char linkname[100];           /* 157 */
  #   char magic[6];                /* 257 */
  #   char version[2];              /* 263 */
  #   char uname[32];               /* 265 */
  #   char gname[32];               /* 297 */
  #   char devmajor[8];             /* 329 */
  #   char devminor[8];             /* 337 */
  #   char prefix[155];             /* 345 */
  #                                 /* 500 */
  # };
  @magic "ustar\0"
  defp parse_header(tar_path, header_block, next_offset) do
    <<filename::100-bytes, mode::8-bytes, uid::8-bytes, gid::8-bytes, size::12-bytes,
      mtime::12-bytes, _chksum::8-bytes, typeflag, linkname::100-bytes, @magic::binary,
      _version::2-bytes, _uname::32-bytes, _gname::32-bytes, major_device::8-bytes,
      minor_device::8-bytes, prefix::155-bytes, _::12-bytes>> = header_block

    %Entry{
      path: trim_null(prefix) <> trim_null(filename),
      contents: {tar_path, next_offset},
      type: typeflag_to_type(typeflag),
      mode: parse_octal(mode),
      uid: parse_octal(uid),
      gid: parse_octal(gid),
      size: parse_octal(size),
      mtime: parse_octal(mtime),
      link: trim_null(linkname),
      major_device: parse_octal(major_device),
      minor_device: parse_octal(minor_device)
    }
  end

  defp typeflag_to_type(0), do: :regular
  defp typeflag_to_type(?0), do: :regular
  defp typeflag_to_type(?1), do: :hard_link
  defp typeflag_to_type(?2), do: :symlink
  defp typeflag_to_type(?3), do: :character_device
  defp typeflag_to_type(?4), do: :block_device
  defp typeflag_to_type(?5), do: :directory
  defp typeflag_to_type(?x), do: :pax_header

  defp parse_octal(str) do
    case trim_null(str) do
      <<>> -> 0
      i -> String.to_integer(i, 8)
    end
  end

  defp trim_null(str) do
    String.trim_trailing(str, <<0>>)
  end
end
