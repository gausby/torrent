defmodule Torrent.File.Swarm.Peer.ReceiverTest do
  use ExUnit.Case
  alias :gen_tcp, as: TCP
  doctest Torrent.File.Swarm.Peer.Receiver

  @info_hash "xxxxxxxxxxxxxxxxxxxx"
  @handshake [19, "BitTorrent Protocol", 0, 0, 0, 0, 0, 0, 0, 0, @info_hash, "yxxxxxxxxxxxxxxxxxxx"]

  test "establish connection if remote ask for a known info_hash" do
    Torrent.Processes.add(@info_hash)
    {:ok, connection} = TCP.connect('localhost', 29182, [active: false])

    TCP.send(connection, [
          19, "BitTorrent Protocol", 0, 0, 0, 0, 0, 0, 0, 0,
          @info_hash, "yxxxxxxxxxxxxxxxxxxx"
        ])

    assert {:ok, [19|_msg]} = TCP.recv(connection, 68)
  end

  test "cut connection if remote ask for an unknown info_hash" do
    {:ok, connection} = TCP.connect('localhost', 29182, [active: false])

    TCP.send(connection, [
          19, "BitTorrent Protocol", 0, 0, 0, 0, 0, 0, 0, 0,
          "does_not_exist_here_", "xxxxxxxxxxxxxxxxxxxx"
        ])

    assert {:error, :closed} = TCP.recv(connection, 68)
  end
end