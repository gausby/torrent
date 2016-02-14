defmodule Torrent.File.PieceManagerTest do
  use ExUnit.Case

  alias Torrent.File.Pieces.{State, Checksums}

  # test "foo" do
  #   {:ok, %{"info" => info} = _data, info_hash} =
  #     File.read!("test/assets/ubuntu-15.10-desktop-amd64.iso.torrent")
  #     |> Bencode.decode_with_info_hash
  #
  #   Torrent.File.Pieces.Store.start_link(info_hash, info)
  # end

  test "store and retrieve checksums" do
    first = <<0,1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,6,7,8,9>>
    second = <<1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,6,7,8,9,0>>
    {:ok, pid} = Checksums.start_link("info_hash", %{"pieces" => IO.iodata_to_binary([first, second])})
    assert first == Checksums.get(pid, 0)
    assert second == Checksums.get(pid, 1)
  end

  test "store bit field" do
    assert {:ok, _pid} = State.start_link("info_hash", %{"length" => 201921, "piece length" => 100})

    State.have("info_hash", 1)
    State.have("info_hash", 8)
    State.have("info_hash", 2019)
    state = State.status("info_hash")
    assert state.pieces == MapSet.new([1, 8, 2019])
    assert state.size == 2020
  end

  test "block controller" do
    info_hash = "hello, world"
    assert {:ok, _pid} = Torrent.File.Pieces.Store.Supervisor.start_link(info_hash, %{"piece length" => 524288})
    assert {:ok, _pid} = Torrent.File.Pieces.Store.Supervisor.add(info_hash, 100)
  end
end