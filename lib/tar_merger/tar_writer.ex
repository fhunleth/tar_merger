defmodule TarMerger.TarWriter do
  @moduledoc false
  alias TarMerger.Entry

  @spec write_tar(Path.t(), [Entry.t()]) :: :ok
  def write_tar(path, entry_list) when is_binary(path) and is_list(entry_list) do
    File.open!(path, [:write], fn file -> write(file, entry_list) end)
  end

  @spec write(File.iodevice(), [Entry.t()]) :: :ok
  def write(out_device, []) do
    # The end marker is 2 empty 512-byte blocks
    :ok = IO.binwrite(out_device, padding_field(1024))
  end

  def write(out_device, [entry | next]) when is_struct(entry) do
    write_header(out_device, entry)
    write_data(out_device, entry)
    write(out_device, next)
  end

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
  defp write_header(out_device, %Entry{} = entry) do
    header1 =
      [
        string_field(entry.path, 100),
        octal_field(entry.mode, 8),
        octal_field(entry.uid, 8),
        octal_field(entry.gid, 8),
        octal_field(entry.size, 12),
        octal_field(0, 12)
      ]
      |> IO.iodata_to_binary()

    header2 =
      [
        type_to_typeflag(entry.type),
        string_field(entry.link, 100),
        "ustar\0",
        "00",
        padding_field(32),
        padding_field(32),
        octal_field(entry.major_device, 8),
        octal_field(entry.minor_device, 8),
        padding_field(155)
      ]
      |> IO.iodata_to_binary()

    cksum = calculate_checksum(header1, header2)
    :ok = IO.binwrite(out_device, [header1, octal_field(cksum, 8), header2, padding_field(12)])
  end

  defp write_data(out_device, %Entry{contents: contents, size: size}) do
    write_contents(out_device, contents, size)

    fragment = rem(size, 512)
    padding = if fragment == 0, do: <<>>, else: padding_field(512 - fragment)
    IO.binwrite(out_device, padding)
  end

  defp write_data(_file, _entry) do
    :ok
  end

  defp write_contents(out_device, {path, offset}, size) when is_binary(path) do
    {:ok, :ok} =
      File.open(path, [:read], fn f ->
        {:ok, data} = :file.pread(f, offset, size)
        IO.binwrite(out_device, data)
      end)

    :ok
  end

  defp write_contents(out_device, {in_device, offset}, size) do
    {:ok, data} = :file.pread(in_device, offset, size)
    IO.binwrite(out_device, data)
  end

  defp calculate_checksum(part1, part2) do
    sum = ?\s * 8

    sum =
      for <<byte <- part1>>, reduce: sum do
        acc -> acc + byte
      end

    for <<byte <- part2>>, reduce: sum do
      acc -> acc + byte
    end
  end

  @spec padding_field(non_neg_integer) :: binary()
  def padding_field(length), do: <<0::integer-size(length)-unit(8)>>

  @spec string_field(String.t(), non_neg_integer) :: binary()
  def string_field(str, length) when is_binary(str), do: zero_pad(str, length)

  @spec octal_field(non_neg_integer, non_neg_integer) :: iolist()
  def octal_field(number, length) when is_integer(number) do
    number_length = length - 1
    octal = :io_lib.format("~#{number_length}.8.0B", [number])

    # Trying to match what GNU tar does which makes sense when reading the spec
    case length - number_length do
      0 -> octal
      1 -> [octal, 0]
      x -> [octal, 0, :binary.copy(" ", x - 1)]
    end
  end

  @spec zero_pad(String.t(), non_neg_integer) :: binary()
  def zero_pad(str, length) when is_binary(str) and is_integer(length) do
    str_size = min(byte_size(str), length)
    pad_amount = length - str_size

    <<str::binary-size(str_size), 0::integer-size(pad_amount)-unit(8)>>
  end

  defp type_to_typeflag(:regular), do: ?0
  defp type_to_typeflag(:hard_link), do: ?1
  defp type_to_typeflag(:symlink), do: ?2
  defp type_to_typeflag(:character_device), do: ?3
  defp type_to_typeflag(:block_device), do: ?4
  defp type_to_typeflag(:directory), do: ?5
end
