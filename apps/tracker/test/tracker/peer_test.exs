defmodule Tracker.PeerTest do
  use ExUnit.Case
  import TrackerTest.Helpers
  doctest Tracker.Peer

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
    torrent_pid = create_torrent()

    {:ok, pid, _trackerid} = create_peer(torrent_pid, %{port: 12340})

    peers = Tracker.Peer.get_peers(pid)
    # the requesting peer should not be in the results
    refute Enum.any?(peers, fn peer -> peer["port"] == 12340 end)
  end

  test "should get a list of peers on request and exclude the calling peer from the results" do
    torrent_pid = create_torrent()

    # spawn some peers
    for {peer_id, port} <- [{"bar", 12341}, {"baz", 12342}, {"quun", 12343}, {"qux", 12344}] do
      create_peer(torrent_pid, %{peer_id: peer_id, port: port})
    end

    test_data = %{peer_id: "foo", port: 12340}
    {:ok, pid, _trackerid} =
      create_peer(torrent_pid, test_data)

    peers = Tracker.Peer.get_peers(pid)
    assert length(peers) == 4
    # the requesting peer should not be in the results
    refute Enum.any?(peers, fn peer -> peer["port"] == test_data[:port] end)
  end

  test "a completed peer should only get incomplete peers back when requesting peers" do
    torrent_pid = create_torrent()

    # spawn some peers
    peers = for {peer_id, port} <- [{"quun", 12343}, {"bar", 12341}, {"baz", 12342}] do
      create_peer(torrent_pid, %{peer_id: peer_id, port: port})
    end

    test_data = %{peer_id: "foo", port: 12340}
    {:ok, pid, trackerid} =
      create_peer(torrent_pid, test_data)

    # complete "foo" and "quun"
    update = %{trackerid: trackerid, event: "completed", left: 0}
    Tracker.Peer.announce(pid, generate_announce_data(update))
    {:ok, quun_pid, quun_trackerid} = hd peers
    update = %{trackerid: quun_trackerid, event: "completed", left: 0}
    Tracker.Peer.announce(quun_pid, generate_announce_data(update))
    :timer.sleep 10

    peers = Tracker.Peer.get_peers(pid)
    assert length(peers) == 2
    # ensure that the ports we get are the expected ones
    ports = Enum.map(peers, &(&1[:port])) |> Enum.sort
    assert ports == [12341, 12342]
  end

  test "when requesting peers the returned list of peers should contain peer ids" do
    torrent_pid = create_torrent()

    # spawn some peers
    for {peer_id, port} <- [{"bar", 12341}, {"baz", 12342}] do
      create_peer(torrent_pid, %{peer_id: peer_id, port: port})
    end

    test_data = %{peer_id: "foo", port: 12340}
    {:ok, pid, _trackerid} =
      create_peer(torrent_pid, test_data)

    peers = Tracker.Peer.get_peers(pid)
    # ensure that the ports we get are the expected ones
    peer_ids = Enum.map(peers, &(&1[:peer_id])) |> Enum.sort
    assert peer_ids == ["bar", "baz"]
  end

  test "peer list should not contain peer ids if no_peer_id is true" do
    torrent_pid = create_torrent()

    # spawn some peers
    for {peer_id, port} <- [{"bar", 12341}, {"baz", 12342}] do
      create_peer(torrent_pid, %{peer_id: peer_id, port: port})
    end

    test_data = %{peer_id: "foo", port: 12340}
    {:ok, pid, _trackerid} =
      create_peer(torrent_pid, test_data)

    peers = Tracker.Peer.get_peers(pid, %{no_peer_id: true})
    # ensure that the ports we get are the expected ones
    peer_ids = Enum.map(peers, &(&1[:peer_id])) |> Enum.sort
    refute peer_ids == ["bar", "baz"]
  end
end
