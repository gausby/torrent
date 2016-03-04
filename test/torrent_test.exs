defmodule TorrentTest do
  use ExUnit.Case
  doctest Torrent

  test "a peer_id should be 20 bytes long" do
    assert <<_::binary-size(20)>> = Torrent.generate_peer_id()
  end

  test "a peer_id should be randomly generated" do
    values =
      Stream.repeatedly(&Torrent.generate_peer_id/0)
      |> Enum.take(100)
      |> Enum.uniq

    assert length(values) == 100
  end

  test "should be able to add a torrent" do
    {:ok, data} = File.read("./test/assets/ubuntu-15.10-desktop-amd64.iso.torrent")
    assert {:ok, _pid} = Torrent.add(data)
  end
end
