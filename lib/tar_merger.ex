defmodule TarMerger do
  @moduledoc """
  PoC for converting tar files and directories to filesystems

  To test:

  ```
  # Copy a rootfs.tar to the local directory. It can be a Nerves system tarball, for example.
  iex> x=TarMerger.read_tar("./rootfs.tar"); :ok
  :ok
  iex> TarMerger.mkfs_erofs("test.erofs", x)
  # Look for the test.erofs file in the current directory
  iex> TarMerger.mkfs_squashfs("test.sqfs", x)
  # Look for the test.sqfs file in the current directory
  ```
  """

  alias TarMerger.Entry
  alias TarMerger.EROFS
  alias TarMerger.FSReader
  alias TarMerger.SquashFS
  alias TarMerger.TarReader
  alias TarMerger.TarWriter

  @type entries() :: [Entry.t()]

  defdelegate scan_directory(path), to: FSReader

  defdelegate read_tar(path), to: TarReader
  defdelegate write_tar(path, entries), to: TarWriter

  @spec merge([entries()]) :: entries()
  def merge(entries_list) when is_list(entries_list) do
    # TODO remove duplicates
    entries_list
    # |> List.concat()
    # |> Enum.sort()
  end

  @doc """
  Create an EROFS image out of the specified entries
  """
  defdelegate mkfs_erofs(erofs_path, entries, options \\ []), to: EROFS

  defdelegate mkfs_squashfs(squashfs_path, entries, options \\ []), to: SquashFS
end
