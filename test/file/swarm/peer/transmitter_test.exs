defmodule Torrent.File.Swarm.Peer.TransmitterTest do
  use ExUnit.Case
  alias :gen_tcp, as: TCP
  doctest Torrent.File.Swarm.Peer.Transmitter

  @info_hash "xxxxxxxxxxxxxxxxxxxx"
  @handshake [19, "BitTorrent Protocol", 0, 0, 0, 0, 0, 0, 0, 0, @info_hash, "yxxxxxxxxxxxxxxxxxxx"]

  test "send choke to remote peer" do
    Torrent.Processes.add(@info_hash)
    {:ok, connection} = TCP.connect('localhost', 29182, [active: false])
    {:ok, my_addr} = :inet.sockname(connection)

    TCP.send(connection, @handshake)
    {:ok, _} = TCP.recv(connection, 68)

    Torrent.File.Swarm.Peer.Transmitter.choke(@info_hash, my_addr)
    assert {:ok, [0, 0, 0, 1, 0]} == TCP.recv(connection, 0)
  end

  test "send unchoke to remote peer" do
    Torrent.Processes.add(@info_hash)
    {:ok, connection} = TCP.connect('localhost', 29182, [active: false])
    {:ok, my_addr} = :inet.sockname(connection)

    TCP.send(connection, @handshake)
    {:ok, _} = TCP.recv(connection, 68)

    Torrent.File.Swarm.Peer.Transmitter.unchoke(@info_hash, my_addr)
    assert {:ok, [0, 0, 0, 1, 1]} == TCP.recv(connection, 0)
  end

  test "send interested to remote peer" do
    Torrent.Processes.add(@info_hash)
    {:ok, connection} = TCP.connect('localhost', 29182, [active: false])
    {:ok, my_addr} = :inet.sockname(connection)

    TCP.send(connection, @handshake)
    {:ok, _} = TCP.recv(connection, 68)

    Torrent.File.Swarm.Peer.Transmitter.interested(@info_hash, my_addr)
    assert {:ok, [0, 0, 0, 1, 2]} == TCP.recv(connection, 0)
  end

  test "send not interest to remote peer" do
    Torrent.Processes.add(@info_hash)
    {:ok, connection} = TCP.connect('localhost', 29182, [active: false])
    {:ok, connection_addr} = :inet.sockname(connection)

    TCP.send(connection, @handshake)
    {:ok, _} = TCP.recv(connection, 68)

    Torrent.File.Swarm.Peer.Transmitter.not_interested(@info_hash, connection_addr)
    assert {:ok, [0, 0, 0, 1, 3]} == TCP.recv(connection, 0)
  end

  test "send have messages to remote peer" do
    Torrent.Processes.add(@info_hash)
    {:ok, connection} = TCP.connect('localhost', 29182, [active: false])
    {:ok, connection_addr} = :inet.sockname(connection)

    TCP.send(connection, @handshake)
    {:ok, _} = TCP.recv(connection, 68)

    Torrent.File.Swarm.Peer.Transmitter.have({@info_hash, connection_addr}, 1)
    assert {:ok, [0, 0, 0, 1, 4, 1]} == TCP.recv(connection, 0)
  end

  test "send bitfield message to remote peer" do
    Torrent.Processes.add(@info_hash)
    {:ok, connection} = TCP.connect('localhost', 29182, [active: false])
    {:ok, connection_addr} = :inet.sockname(connection)

    TCP.send(connection, @handshake)
    {:ok, _} = TCP.recv(connection, 68)

    Torrent.File.Swarm.Peer.Transmitter.bitfield({@info_hash, connection_addr}, BitFieldSet.new(<<101, 128, 42>>))
    assert {:ok, [0, 0, 0, 4, 5, 101, 128, 42]} == TCP.recv(connection, 0)
  end
end
