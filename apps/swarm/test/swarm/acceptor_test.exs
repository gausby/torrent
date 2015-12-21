defmodule Swarm.AcceptorTest do
  use ExUnit.Case
  alias :gen_tcp, as: TCP
  doctest Swarm.Acceptor

  @info_hash "xxxxxxxxxxxxxxxxxxxx"
  test "the truth" do
    {:ok, connection} = TCP.connect('localhost', 29182, [active: false])

    TCP.send(connection, [
          19, "BitTorrent Protocol", 0, 0, 0, 0, 0, 0, 0, 0,
          @info_hash, "yxxxxxxxxxxxxxxxxxxx"
        ])

    assert {:ok, [19|_msg]} = TCP.recv(connection, 68)
  end
end
