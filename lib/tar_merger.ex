defmodule TarMerger do
  @moduledoc """
  PoC for converting tar files and directories to filesystems

  To test:

  ```
  # Copy a rootfs.tar to the local directory. It can be a Nerves system tarball, for example.
  iex> x=TarMerger.read_tar("./rootfs.tar"); :ok
  :ok
  iex> TarMerger.mkfs_erofs("test.erofs", x)
  # Look for the test.erofs file on disk
  ```
  """

  alias TarMerger.FSReader
  alias TarMerger.TarReader
  alias TarMerger.TarWriter

  defdelegate scan_directory(path), to: FSReader

  defdelegate read_tar(path), to: TarReader
  defdelegate write_tar(path, entries), to: TarWriter

  def merge(entries_list) when is_list(entries_list) do
    # TODO remove duplicates
    entries_list
    # |> List.concat()
    # |> Enum.sort()
  end

  @doc """
  Create an EROFS image out of the specified entries
  """
  def mkfs_erofs(erofs_path, entries) do
    tar_path = erofs_path <> ".tar"
    write_tar(tar_path, entries)

    System.cmd("mkfs.erofs", [
      "-zlz4hc",
      "-U",
      "00000000-0000-0000-0000-000000000000",
      "--tar",
      erofs_path,
      tar_path
    ])
  end
end
