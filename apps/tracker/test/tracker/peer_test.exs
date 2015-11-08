defmodule Tracker.PeerTest do
  use ExUnit.Case
  doctest Tracker.Peer

  @info_hash "xxxxxxxxxxxxxxxxxxxx"
  @dummy_meta_info %{info_hash: "xxxxxxxxxxxxxxxxxxxx", size: 100, name: "test"}

  setup_all do
    :ok = Logger.remove_backend(:console)
    on_exit(fn -> Logger.add_backend(:console, flush: true) end)

    Tracker.start(:normal, [])
    :ok
  end

  setup do
    # stop all tracked torrents
    match = {{:n, :l, {Tracker.Torrent, :'_'}}, :'$1', :'_'}
    for torrent <- :gproc.select([{match, [], [:'$1']}]) do
      Tracker.Torrent.stop(torrent)
    end

    # kill loose peers, if some test should leave some behind
    match = {{:n, :l, {Tracker.Peer, :'_', :'_'}}, :'$1', :'_'}
    for peer <- :gproc.select([{match, [], [:'$1']}]) do
      Tracker.Peer.stop(peer)
    end
    :ok
  end

  test "should return an empty list if no other peers are registered" do
    torrent_pid = Tracker.Torrent.create(@dummy_meta_info)
    key = {:n, :l, {Tracker.Torrent, @info_hash}}
    assert torrent_pid == :gproc.where(key)

    # spawn a peer
    test_data =
      %{info_hash: @info_hash,
        ip: {127, 0, 0, 1}, port: 31337,
        peer_id: "foo",
        event: "started",
        downloaded: 0,
        uploaded: 0,
        left: 700}

    {:ok, pid, _trackerid} =
      Tracker.Torrent.add_peer(torrent_pid, test_data)

    peers = Bencode.decode(Tracker.Peer.get_peers(pid))
    # the original test_data should not be in the results
    refute Enum.any?(peers, fn peer -> peer["port"] == test_data[:port] end)
  end

  test "should get a list of peers on request and exclude the calling peer from the results" do
    torrent_pid = Tracker.Torrent.create(@dummy_meta_info)
    key = {:n, :l, {Tracker.Torrent, @info_hash}}
    assert torrent_pid == :gproc.where(key)

    # spawn some peers
    test_data =
      %{info_hash: @info_hash,
        ip: {127, 0, 0, 1}, port: 31337,
        peer_id: "foo",
        event: "started",
        downloaded: 0,
        uploaded: 0,
        left: 700}

    for {peer, port} <- [{"bar", 31338}, {"baz", 31339}, {"quun", 31340}, {"qux", 31341}] do
      peer = Map.merge(test_data, %{peer_id: peer, port: port})
      {:ok, pid, trackerid} =
        Tracker.Torrent.add_peer(torrent_pid, peer)
      {pid, trackerid}
    end

    {:ok, pid, _trackerid} =
      Tracker.Torrent.add_peer(torrent_pid, test_data)

    peers = Bencode.decode(Tracker.Peer.get_peers(pid))
    # the original test_data should not be in the results
    refute Enum.any?(peers, fn peer -> peer["port"] == test_data[:port] end)
  end

end
