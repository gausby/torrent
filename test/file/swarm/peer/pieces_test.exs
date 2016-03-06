defmodule Torrent.File.Swarm.Peer.PiecesTest do
  use ExUnit.Case
  doctest Torrent.File.Swarm.Peer.Pieces

  alias Torrent.File.Swarm.Peer.Pieces

  @info_hash "xxxxxxxxxxxxxxxxxxxx"
  @ip {127, 0, 0, 1}
  @port 61281
  @port_and_ip {@port, @ip}
  @via_name {@info_hash, @port_and_ip}

  test "marking pieces as have" do
    {:ok, _pid} = Pieces.start_link(@info_hash, @port_and_ip, %{"length" => 320, "piece length" => 1})
    refute Pieces.has?(@via_name, 1)

    Pieces.have(@via_name, 1)
    assert Pieces.has?(@via_name, 1)
  end

  test "should be able to overwrite state" do
    {:ok, _pid} = Pieces.start_link(@info_hash, @port_and_ip, %{"length" => 320, "piece length" => 1})
    assert Pieces.status(@via_name).pieces == MapSet.new
    assert :ok = Pieces.overwrite(@via_name, <<128, 128, 128, 128, 128, 128, 128, 128>>)
    assert Pieces.status(@via_name).pieces == MapSet.new([0, 8, 16, 24, 32, 40, 48, 56])
  end

  # test "should return an error if bitfield size does not match state when overwriting" do
  #   {:ok, _pid} = Pieces.start_link(@info_hash, @port_and_ip)
  #   assert {:error, _} = Pieces.overwrite(@via_name, <<128, 128, 128, 128, 128, 128, 128, 128, 128>>)
  # end
end
