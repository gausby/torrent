defmodule Bencode.EncoderTest do
  use ExUnit.Case
  doctest Bencode.Encoder

  test "Bencode encoding strings" do
    assert Bencode.Encoder.encode("") == "0:"
    assert Bencode.Encoder.encode("josé") == "4:josé"
  end

  test "Bencode encoding integers" do
    assert Bencode.Encoder.encode(0) == "i0e"
    assert Bencode.Encoder.encode(-42) == "i-42e"
  end

  test "Bencode encoding lists" do
    assert Bencode.Encoder.encode(["spam", 42]) == "l4:spami42ee"
  end

  test "Bencode encoding dictionaries" do
    assert Bencode.Encoder.encode(%{"bar" => "spam", "foo" => 42}) == "d3:bar4:spam3:fooi42ee"
  end
end
