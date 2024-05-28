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
  alias TarMerger.SquashFS2
  alias TarMerger.TarReader
  alias TarMerger.TarWriter

  @type entries() :: [Entry.t()]

  @spec run_example() :: :ok
  def run_example() do
    system = TarMerger.read_tar("./rootfs.tar") |> sort()

    IO.puts("Creating EROFS")
    TarMerger.mkfs_erofs("test.erofs", system)
    IO.puts("Creating SquashFS")
    TarMerger.mkfs_squashfs("test.sqfs", system)
    IO.puts("Done")
  end

  defdelegate scan_directory(path, root \\ "/"), to: FSReader

  defdelegate read_tar(path), to: TarReader
  defdelegate write_tar(path, entries), to: TarWriter

  @doc """
  Merge multiple sets of files together

  In the case of duplicates, first entry wins, so order the file sets from
  highest priority to lowest.
  """
  @spec merge([entries()]) :: entries()
  def merge(entries_list) when is_list(entries_list) do
    entries_list
    |> List.flatten()
    |> Enum.uniq_by(fn entry -> entry.path end)
  end

  @doc """
  Sort the entries
  """
  @spec sort(entries()) :: entries()
  def sort(entries) do
    entries
    |> Enum.sort(&dirs_first_then_alpha/2)
  end

  defp dirs_first_then_alpha(a, b) do
    if a.type == :directory do
      if b.type == :directory do
        a.path <= b.path
      else
        true
      end
    else
      if b.type == :directory do
        false
      else
        a.path <= b.path
      end
    end
  end

  @doc """
  Create an EROFS image out of the specified entries
  """
  defdelegate mkfs_erofs(erofs_path, entries, options \\ []), to: EROFS

  defdelegate mkfs_squashfs(squashfs_path, entries, options \\ []), to: SquashFS2
end
