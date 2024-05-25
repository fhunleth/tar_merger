defmodule TarMerger.SquashFSTest do
  use ExUnit.Case
  alias TarMerger.Entry
  alias TarMerger.SquashFS
  doctest SquashFS

  defp entries() do
    [
      Entry.directory("/dev", mode: 0o755),
      Entry.block_device("/dev/block", mode: 0o644, major_device: 1, minor_device: 2),
      Entry.character_device("/dev/ttyS0", mode: 0o644, major_device: 3, minor_device: 4),
      Entry.symlink("/dev/ttyABC", mode: 0o755, link: "ttyS0"),
      Entry.directory("/sbin", mode: 0o755),
      Entry.regular("/sbin/init", mode: 0o777, contents: {"path/to/sbin/init", 0}, size: 1000),
      Entry.directory("/bin", mode: 0o755),
      Entry.regular("/bin/busybox", mode: 0o755, contents: {"path/to/bin/busybox", 0}, size: 1000)
    ]
  end

  test "pseudofile/1" do
    pseudofile = entries() |> SquashFS.pseudo_file() |> IO.iodata_to_binary()

    assert pseudofile == """
           /dev/ m 755 0 0
           /dev/block b 644 0 0 1 2
           /dev/ttyS0 c 644 0 0 3 4
           /dev/ttyABC s 755 0 0 ttyS0
           /sbin/ m 755 0 0
           /sbin/init m 777 0 0
           /bin/ m 755 0 0
           /bin/busybox m 755 0 0
           """
  end

  test "sort_file/1" do
    pseudofile = entries() |> SquashFS.sort_file() |> IO.iodata_to_binary()

    assert pseudofile == """
           path/to/sbin/init -32768
           path/to/bin/busybox -32767
           """
  end
end
