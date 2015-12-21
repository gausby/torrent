defmodule PeerWireTest do
  use ExUnit.Case
  doctest PeerWire

  alias :gen_tcp, as: TCP

  test "handshake" do
    {:ok, client} = TCP.connect('localhost', 9000, [active: false])

    reserved = [0, 0, 0, 0, 0, 0, 0, 0]
    info_hash = "xxxxxxxxxxxxxxxxxxxx"
    peer_id = "zzzzzzzzzzzzzzzzzzzz"
    header = [19, "BitTorrent Protocol", reserved]
    TCP.send(client, header)
    TCP.send(client, info_hash)
    TCP.send(client, peer_id)

    IO.inspect TCP.recv(client, 68)
  end
end
