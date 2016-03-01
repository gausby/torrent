defmodule Torrent.File.PieceManagerTest do
  use ExUnit.Case

  alias Torrent.File.Pieces.{State, Checksums}
  alias Torrent.File.Pieces.Store.Blocks.Block

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
    assert {:ok, _pid} = Torrent.File.Pieces.Store.Supervisor.add(info_hash, 100, :crypto.hash(:sha, "foo"))
  end

  test "set and retrieve candidates on a block" do
    info_hash = "hello, world 2"
    assert {:ok, _pid} = Torrent.File.Pieces.Store.Supervisor.start_link(info_hash, %{"piece length" => 524288})
    assert {:ok, _pid} = Torrent.File.Pieces.Store.Supervisor.add(info_hash, 100, :crypto.hash(:sha, "foo"))

    # should start out with empty candidate list
    assert %{} = Block.get_candidates({info_hash, 100, 0, 16*1024})

    # adding a candidate should update the candidate list
    assert Block.add_candidate({info_hash, 100, 0, 16*1024}, {"foo", "bar"})
    assert Block.get_candidates({info_hash, 100, 0, 16*1024}) ==
      Map.put(%{}, :crypto.hash(:sha, "foo"), {"foo", MapSet.new(["bar"])})

    # adding the same candidate should keep the candidate list as is
    assert Block.add_candidate({info_hash, 100, 0, 16*1024}, {"foo", "bar"})
    assert Block.get_candidates({info_hash, 100, 0, 16*1024}) ==
      Map.put(%{}, :crypto.hash(:sha, "foo"), {"foo", MapSet.new(["bar"])})

    # adding the same candidate from a different provider should should update
    assert Block.add_candidate({info_hash, 100, 0, 16*1024}, {"foo", "baz"})
    assert Block.get_candidates({info_hash, 100, 0, 16*1024}) ==
      Map.put(%{}, :crypto.hash(:sha, "foo"), {"foo", MapSet.new(["baz", "bar"])})

    # adding another candidate should update the candidate list
    assert Block.add_candidate({info_hash, 100, 0, 16*1024}, {"foobar", "foo"})
    assert Block.get_candidates({info_hash, 100, 0, 16*1024}) ==
      %{}
      |> Map.put(:crypto.hash(:sha, "foo"), {"foo", MapSet.new(["baz", "bar"])})
      |> Map.put(:crypto.hash(:sha, "foobar"), {"foobar", MapSet.new(["foo"])})
  end

  test "validate pieces when all blocks has been received" do
    info_hash = "hello, world 3"
    peer_name = "xxxxxxxxxxxxxxxxxxxx"
    Torrent.File.Pieces.Store.Supervisor.start_link(info_hash, %{"piece length" => 32, "block length" => 8})
    assert {:ok, _pid} = Torrent.File.Pieces.Store.Supervisor.add(info_hash, 0, :crypto.hash(:sha, "abcd"))

    Block.add_candidate({info_hash, 0, 0, 8}, {"a", peer_name})
    Block.add_candidate({info_hash, 0, 8, 8}, {"b", peer_name})
    Block.add_candidate({info_hash, 0, 16, 8}, {"c", peer_name})
    Block.add_candidate({info_hash, 0, 24, 8}, {"d", peer_name})
    :timer.sleep 100
    # todo, find a way to validate that it actually retrieved and ran the checksum on the data
  end
end
