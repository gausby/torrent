defmodule TorrentTest do
  use ExUnit.Case
  alias :gen_tcp, as: TCP
  doctest Torrent

  setup_all do
    :ok = Logger.remove_backend(:console)
    on_exit(fn -> Logger.add_backend(:console, flush: true) end)
    :ok
  end

  @info_hash "xxxxxxxxxxxxxxxxxxxx"
  @handshake [19, "BitTorrent Protocol", 0, 0, 0, 0, 0, 0, 0, 0, @info_hash, "yxxxxxxxxxxxxxxxxxxx"]

  test "establish connection if remote ask for a known info_hash" do
    Torrent.File.Supervisor.add(@info_hash)
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

  test "establish stuff" do
    Torrent.File.Supervisor.add(@info_hash)
    {:ok, connection} = TCP.connect('localhost', 29182, [active: false])

    # perform handshake
    TCP.send(connection, [
          19, "BitTorrent Protocol", 0, 0, 0, 0, 0, 0, 0, 0,
          @info_hash, "yxxxxxxxxxxxxxxxxxxx"
        ])
    {:ok, _} = TCP.recv(connection, 68)

    # send bitfield
    bitfield = <<255, 212, 1, 42>>
    size = byte_size(bitfield) + 1
    bitfield_message = IO.iodata_to_binary([<<size::big-integer-size(32), 5>>, [bitfield]])
    TCP.send(connection, bitfield_message)
  end


  test "send choke to remote peer" do
    Torrent.File.Supervisor.add(@info_hash)
    {:ok, connection} = TCP.connect('localhost', 29182, [active: false])
    {:ok, my_addr} = :inet.sockname(connection)

    TCP.send(connection, @handshake)
    {:ok, _} = TCP.recv(connection, 68)

    Torrent.File.Swarm.Peer.Transmitter.choke(@info_hash, my_addr)
    assert {:ok, [0, 0, 0, 1, 0]} == TCP.recv(connection, 0)
  end

  test "send unchoke to remote peer" do
    Torrent.File.Supervisor.add(@info_hash)
    {:ok, connection} = TCP.connect('localhost', 29182, [active: false])
    {:ok, my_addr} = :inet.sockname(connection)

    TCP.send(connection, @handshake)
    {:ok, _} = TCP.recv(connection, 68)

    Torrent.File.Swarm.Peer.Transmitter.unchoke(@info_hash, my_addr)
    assert {:ok, [0, 0, 0, 1, 1]} == TCP.recv(connection, 0)
  end

  test "send interested to remote peer" do
    Torrent.File.Supervisor.add(@info_hash)
    {:ok, connection} = TCP.connect('localhost', 29182, [active: false])
    {:ok, my_addr} = :inet.sockname(connection)

    TCP.send(connection, @handshake)
    {:ok, _} = TCP.recv(connection, 68)

    Torrent.File.Swarm.Peer.Transmitter.interested(@info_hash, my_addr)
    assert {:ok, [0, 0, 0, 1, 2]} == TCP.recv(connection, 0)
  end

  test "send not interest to remote peer" do
    Torrent.File.Supervisor.add(@info_hash)
    {:ok, connection} = TCP.connect('localhost', 29182, [active: false])
    {:ok, connection_addr} = :inet.sockname(connection)

    TCP.send(connection, @handshake)
    {:ok, _} = TCP.recv(connection, 68)

    Torrent.File.Swarm.Peer.Transmitter.not_interested(@info_hash, connection_addr)
    assert {:ok, [0, 0, 0, 1, 3]} == TCP.recv(connection, 0)
  end
end
