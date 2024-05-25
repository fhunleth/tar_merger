defmodule TarMerger.TarWriterTest do
  use ExUnit.Case
  alias TarMerger.TarWriter
  doctest TarWriter

  test "padding_field/1" do
    assert TarWriter.padding_field(8) == <<0, 0, 0, 0, 0, 0, 0, 0>>
  end

  test "string_field/2" do
    assert TarWriter.string_field("abc", 8) == <<?a, ?b, ?c, 0, 0, 0, 0, 0>>
  end

  test "octal_field/2" do
    assert IO.iodata_to_binary(TarWriter.octal_field(0o755, 8)) == "0000755\0"
  end
end
