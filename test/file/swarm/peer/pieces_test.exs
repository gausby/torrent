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
    {:ok, _pid} = Pieces.start_link(@info_hash, @port_and_ip)
    refute Pieces.has?(@via_name, 1)

    Pieces.have(@via_name, 1)

    assert Pieces.has?(@via_name, 1)
  end
end
