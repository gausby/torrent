defmodule Bencode.DecoderTest do
  use ExUnit.Case
  doctest Bencode.Decoder

  test "decode integers" do
    assert Bencode.decode("i42e") == 42
    assert Bencode.decode("i-42e") == -42
    assert Bencode.decode("i0e") == 0
  end

  test "decode strings" do
    assert Bencode.decode("3:foo") == "foo"
    assert Bencode.decode("0:") == ""
    assert Bencode.decode("1:a") == "a"
  end

  test "decode list" do
    assert Bencode.decode("l3:fooi42ee") == ["foo", 42]
    assert Bencode.decode("l3:foo3:bar3:baz4:quune") == ["foo", "bar", "baz", "quun"]
  end

  test "decode dictionary" do
    assert Bencode.decode("d3:foo3:bare") == %{"foo" => "bar"}
    assert Bencode.decode("d3:fooi5ee") == %{"foo" => 5}
  end
end
