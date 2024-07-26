defmodule TarMerger.Entry do
  @moduledoc """
  A module to read a tar file and return a list of maps containing filename,
  offset, and permissions.
  """

  defstruct path: "",
            contents: nil,
            type: :regular,
            mode: 0,
            uid: 0,
            gid: 0,
            size: 0,
            mtime: 0,
            link: "",
            major_device: 0,
            minor_device: 0

  @type entry_type ::
          :regular
          | :hard_link
          | :symlink
          | :character_device
          | :block_device
          | :directory
          | :pax_header
          | :long_name

  @type t() :: %__MODULE__{
          path: String.t(),
          contents: nil | {Path.t(), non_neg_integer()} | {File.io_device(), non_neg_integer()},
          type: entry_type(),
          mode: non_neg_integer(),
          uid: non_neg_integer(),
          gid: non_neg_integer(),
          link: String.t(),
          size: non_neg_integer(),
          mtime: non_neg_integer(),
          major_device: non_neg_integer(),
          minor_device: non_neg_integer()
        }

  @spec regular(String.t(), keyword()) :: t()
  def regular(path, info) do
    %__MODULE__{
      path: normalize_path(path),
      type: :regular,
      contents: Keyword.fetch!(info, :contents),
      mode: Keyword.fetch!(info, :mode) |> normalize_mode(),
      size: Keyword.fetch!(info, :size)
    }
  end

  @spec directory(String.t(), keyword()) :: t()
  def directory(path, info) do
    %__MODULE__{
      path: path |> normalize_path() |> normalize_dir(),
      type: :directory,
      mode: Keyword.fetch!(info, :mode) |> normalize_mode()
    }
  end

  @spec symlink(String.t(), keyword()) :: t()
  def symlink(path, info) do
    %__MODULE__{
      path: normalize_path(path),
      type: :symlink,
      mode: Keyword.fetch!(info, :mode) |> normalize_mode(),
      link: Keyword.fetch!(info, :link),
      size: 0
    }
  end

  @spec block_device(String.t(), keyword()) :: t()
  def block_device(path, info) do
    %__MODULE__{
      path: normalize_path(path),
      type: :block_device,
      mode: Keyword.fetch!(info, :mode) |> normalize_mode(),
      size: 0,
      major_device: Keyword.fetch!(info, :major_device),
      minor_device: Keyword.fetch!(info, :minor_device)
    }
  end

  @spec character_device(String.t(), keyword()) :: t()
  def character_device(path, info) do
    %__MODULE__{
      path: normalize_path(path),
      type: :character_device,
      mode: Keyword.fetch!(info, :mode) |> normalize_mode(),
      size: 0,
      major_device: Keyword.fetch!(info, :major_device),
      minor_device: Keyword.fetch!(info, :minor_device)
    }
  end

  @spec put_path(t(), String.t()) :: t()
  def put_path(entry, path) do
    %{entry | path: normalize_path(path)}
  end

  @spec read_contents(t()) :: {:ok, binary() | iolist()} | {:error, :file.posix() | :eof}
  def read_contents(%__MODULE__{contents: nil}), do: {:ok, <<>>}

  def read_contents(%__MODULE__{contents: {io_device, offset}} = entry) when is_pid(io_device) do
    case :file.pread(io_device, offset, entry.size) do
      {:ok, data} -> {:ok, data}
      :eof -> {:error, :eof}
      err -> {:error, err}
    end
  end

  def read_contents(%__MODULE__{contents: {path, offset}} = entry) when is_binary(path) do
    with {:ok, file} <- File.open(path, [:read]),
         {:ok, data} <- :file.pread(file, offset, entry.size) do
      _ = :file.close(file)
      {:ok, data}
    else
      :eof -> {:error, :eof}
      err -> err
    end
  end

  defp normalize_mode(mode) do
    Bitwise.band(mode, 0o7777)
  end

  defp normalize_path("../" <> path),
    do: raise(RuntimeError, "Previous directory not supported in path: ../#{path}")

  defp normalize_path("./" <> path), do: "./" <> path
  defp normalize_path("/" <> path), do: "./" <> path
  defp normalize_path(path), do: "./" <> path

  defp normalize_dir(path) do
    # Tarball directories always end with /'s
    if String.ends_with?(path, "/") do
      path
    else
      path <> "/"
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    @impl Inspect
    def inspect(%{type: :regular} = entry, opts) do
      concat([
        "TarMerger.Entry.regular(",
        Inspect.inspect(entry.path, opts),
        ", contents: ",
        Inspect.inspect(entry.contents, opts),
        ", mode: ",
        Inspect.inspect(entry.mode, Map.put(opts, :base, :octal)),
        ", size: ",
        Inspect.inspect(entry.size, opts),
        ")"
      ])
    end

    def inspect(%{type: :directory} = entry, opts) do
      concat([
        "TarMerger.Entry.directory(",
        Inspect.inspect(entry.path, opts),
        ", mode: ",
        Inspect.inspect(entry.mode, Map.put(opts, :base, :octal)),
        ")"
      ])
    end

    def inspect(%{type: :symlink} = entry, opts) do
      concat([
        "TarMerger.Entry.symlink(",
        Inspect.inspect(entry.path, opts),
        ", mode: ",
        Inspect.inspect(entry.mode, Map.put(opts, :base, :octal)),
        ", link: ",
        Inspect.inspect(entry.link, opts),
        ")"
      ])
    end

    def inspect(%{type: :block_device} = entry, opts) do
      concat([
        "TarMerger.Entry.block_device(",
        Inspect.inspect(entry.path, opts),
        ", mode: ",
        Inspect.inspect(entry.mode, Map.put(opts, :base, :octal)),
        ", major_device: ",
        Inspect.inspect(entry.major_device, opts),
        ", minor_device: ",
        Inspect.inspect(entry.minor_device, opts),
        ")"
      ])
    end

    def inspect(%{type: :character_device} = entry, opts) do
      concat([
        "TarMerger.Entry.character_device(",
        Inspect.inspect(entry.path, opts),
        ", mode: ",
        Inspect.inspect(entry.mode, Map.put(opts, :base, :octal)),
        ", major_device: ",
        Inspect.inspect(entry.major_device, opts),
        ", minor_device: ",
        Inspect.inspect(entry.minor_device, opts),
        ")"
      ])
    end

    def inspect(%{type: :pax_header} = entry, opts) do
      concat([
        "TarMerger.Entry.pax_header(",
        Inspect.inspect(entry.path, opts),
        ", contents: ",
        Inspect.inspect(entry.contents, opts),
        ", mode: ",
        Inspect.inspect(entry.mode, Map.put(opts, :base, :octal)),
        ", size: ",
        Inspect.inspect(entry.size, opts),
        ")"
      ])
    end

    def inspect(%{type: :long_name} = entry, opts) do
      concat([
        "TarMerger.Entry.long_name(",
        Inspect.inspect(entry.path, opts),
        ", contents: ",
        Inspect.inspect(entry.contents, opts),
        ", mode: ",
        Inspect.inspect(entry.mode, Map.put(opts, :base, :octal)),
        ", size: ",
        Inspect.inspect(entry.size, opts),
        ")"
      ])
    end
  end
end
