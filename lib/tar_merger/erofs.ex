defmodule TarMerger.EROFS do
  @moduledoc false
  import TarMerger.Util
  alias TarMerger.Entry

  @type options() :: [
          tmp_dir: Path.t(),
          erofs_options: [String.t()],
          compressor: :lz4 | :lz4hc | :lzma | :deflate
        ]

  @spec mkfs_erofs(Path.t(), [Entry.t()], options()) :: :ok | :error
  def mkfs_erofs(erofs_path, entries, options \\ []) when is_list(entries) do
    tmp_dir = Keyword.get_lazy(options, :tmp_dir, &System.tmp_dir!/0)
    extra_options = Keyword.get(options, :erofs_options, [])

    tar_path = Path.join(tmp_dir, "erofs_root.tar")

    TarMerger.write_tar(tar_path, entries)

    cmd(
      "mkfs.erofs",
      mkfs_erofs_options(options) ++
        [
          "-U",
          "00000000-0000-0000-0000-000000000000",
          "--tar",
          erofs_path,
          tar_path
        ] ++ extra_options
    )
  end

  defp mkfs_erofs_options(options) do
    [
      compressor_options(options)
    ]
    |> List.flatten()
  end

  defp compressor_options(options) do
    case Keyword.fetch(options, :compressor) do
      {:ok, :lz4hc} -> ["-zlz4hc"]
      {:ok, :lzma} -> ["-zlzma"]
      {:ok, :lz4} -> ["-zlz"]
      {:ok, :deflate} -> ["-zdeflate"]
      {:ok, other} -> raise ArgumentError, "Don't know #{inspect(other)} compressor"
      :error -> ["-zlz4hc"]
    end
  end
end
