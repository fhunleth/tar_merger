defmodule TarMerger.EROFS do
  @moduledoc false
  import TarMerger.Util
  alias TarMerger.Entry

  @type options() :: [tmp_dir: Path.t(), erofs_options: [String.t()]]

  @spec mkfs_erofs(Path.t(), [Entry.t()], options()) :: :ok | :error
  def mkfs_erofs(erofs_path, entries, options \\ []) when is_list(entries) do
    tmp_dir = Keyword.get_lazy(options, :tmp_dir, &System.tmp_dir!/0)
    erofs_options = Keyword.get(options, :erofs_options, [])

    tar_path = Path.join(tmp_dir, "erofs_root.tar")

    TarMerger.write_tar(tar_path, entries)

    cmd("mkfs.erofs", [
      "-zlz4hc",
      "-U",
      "00000000-0000-0000-0000-000000000000",
      "--tar",
      erofs_path,
      tar_path | erofs_options
    ])
  end
end
