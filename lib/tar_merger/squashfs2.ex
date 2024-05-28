defmodule TarMerger.SquashFS2 do
  @moduledoc false

  alias TarMerger.Entry

  @type options() :: [
          tmp_dir: Path.t(),
          erofs_options: [String.t()],
          compressor: :lz4 | :lz4hc | :lzma | :deflate
        ]

  @spec mkfs_squashfs(Path.t(), [Entry.t()], options()) :: :ok | :error
  def mkfs_squashfs(squashfs_path, entries, options \\ []) when is_list(entries) do
    tmp_dir = Keyword.get_lazy(options, :tmp_dir, &System.tmp_dir!/0)

    tar_path = Path.join(tmp_dir, "squashfs_root.tar")
    TarMerger.write_tar(tar_path, entries)

    System.shell("sqfstar -force #{mksquashfs_options(options)} #{squashfs_path} < #{tar_path}")
  end

  defp mksquashfs_options(options) do
    [
      compressor_options(options),
      extra_options(options)
    ]
    |> Enum.reject(fn x -> x == "" end)
    |> Enum.intersperse(?\s)
    |> IO.iodata_to_binary()
  end

  defp compressor_options(options) do
    case Keyword.fetch(options, :compressor) do
      {:ok, :gzip} -> "-comp gzip"
      {:ok, :lzo} -> "-comp lzo"
      {:ok, :lz4} -> "-comp lz4"
      {:ok, :zstd} -> "-comp zstd"
      {:ok, other} -> raise ArgumentError, "Don't know #{inspect(other)} compressor"
      :error -> "-comp gzip"
    end
  end

  defp extra_options(options) do
    Keyword.get(options, :mksquashfs_options, "")
  end
end
