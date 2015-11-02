defmodule Tracker.TorrentTest do
  use ExUnit.Case
  doctest Tracker.Torrent

  @info_hash "xxxxxxxxxxxxxxxxxxxx"
  @dummy_meta_info %{info_hash: "xxxxxxxxxxxxxxxxxxxx", size: 100, name: "test"}

  setup_all do
    Tracker.start(:normal, [])
    :ok
  end

  setup do
    match = {{:n, :l, {Tracker.Peer, :'_', :'_'}}, :'$1', :'_'}
    for peer <- :gproc.select([{match, [], [:'$1']}]) do
      Tracker.Peer.stop(peer)
    end

    :ok
  end

  # Adding a new torrent ===============================================
  test "should register a new torrent" do
    pid = Tracker.Torrent.create(@dummy_meta_info)
    assert ^pid = :gproc.where({:n, :l, {Tracker.Torrent, @info_hash}})
  end

  test "should return the same pid when registering the same info_hash twice (or more)" do
    pid1 = Tracker.Torrent.create(@dummy_meta_info)
    pid2 = Tracker.Torrent.create(@dummy_meta_info)
    assert pid1 == pid2
  end

  test "should be able to track peers" do
    torrent_pid = Tracker.Torrent.create(@dummy_meta_info)
    {:ok, pid, _} =
      Tracker.Torrent.add_peer(torrent_pid, %{event: "started",
                                              info_hash: @info_hash,
                                              ip: {127, 0, 0, 1}, port: 31337,
                                              peer_id: "hello",
                                              uploaded: 0,
                                              downloaded: 0,
                                              left: 0})
    assert [^pid] = Tracker.Torrent.list_all_peers(@info_hash)
  end

  # Removing a torrent =================================================
  test "should remove all peers when shutting down on purpose" do
    torrent_pid = Tracker.Torrent.create(@dummy_meta_info)

    for peer <- ["foo", "bar", "baz"] do
      Tracker.Torrent.add_peer(torrent_pid, %{event: "started",
                                              info_hash: @info_hash,
                                              ip: {127, 0, 0, 1}, port: 31337,
                                              peer_id: peer,
                                              uploaded: 0,
                                              downloaded: 0,
                                              left: 0})
    end
    assert length(Tracker.Torrent.list_all_peers(@info_hash)) == 3
    Tracker.Torrent.stop(torrent_pid)
    assert Process.alive?(torrent_pid) == false
    assert length(Tracker.Torrent.list_all_peers(@info_hash)) == 0
  end

  # Randomly killing a new torrent =====================================
  # test "when killed it should respawn and collect data from the peers"

  # Statistics =========================================================

  # 'incomplete' peers downloading, "leeching"
  # 'complete' peers marked as done, "seeders"
  # 'downloads' completed downloads since beginning of time

  # peer joining -------------------------------------------------------
  test "should update incomplete statistics when a new peer joins" do
    torrent_pid = Tracker.Torrent.create(@dummy_meta_info)
    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0

    test_data =
      %{info_hash: @info_hash,
        ip: {127, 0, 0, 1}, port: 31337,
        peer_id: "foo",
        event: "started",
        downloaded: 0,
        uploaded: 0,
        left: 700}
    Tracker.Torrent.add_peer(torrent_pid, test_data)
    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 1
  end

  test "should not increment 'downloads' when a peer joins and announce 0 left" do
    torrent_pid = Tracker.Torrent.create(@dummy_meta_info)
    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :downloads}, torrent_pid) == 0

    test_data =
      %{info_hash: @info_hash,
        ip: {127, 0, 0, 1}, port: 31337,
        peer_id: "foo",
        event: "started",
        downloaded: 0,
        uploaded: 0,
        left: 700}
    Tracker.Torrent.add_peer(torrent_pid, test_data)
    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :downloads}, torrent_pid) == 0
  end

  # peer completing ----------------------------------------------------
  test "should increment its complete statistics and decrement its incomplete statistics when a peer complete" do
    torrent_pid = Tracker.Torrent.create(@dummy_meta_info)
    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 0
    assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0

    test_data =
      %{info_hash: @info_hash,
        ip: {127, 0, 0, 1}, port: 31337,
        peer_id: "foo",
        event: "started",
        downloaded: 0,
        uploaded: 0,
        left: 700}
    {:ok, pid, trackerid} = Tracker.Torrent.add_peer(torrent_pid, test_data)

    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 1
    assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 0

    update =
      %{event: "completed",
        trackerid: trackerid,
        downloaded: 700,
        uploaded: 600,
        left: 0}
    Tracker.Peer.announce(pid, Map.merge(test_data, update))
    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0
    assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 1
  end

  test "should increment its downloads statistics when a peer complete" do
    torrent_pid = Tracker.Torrent.create(@dummy_meta_info)
    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :downloads}, torrent_pid) == 0

    test_data =
      %{info_hash: @info_hash,
        ip: {127, 0, 0, 1}, port: 31337,
        peer_id: "foo",
        event: "started",
        downloaded: 0,
        uploaded: 0,
        left: 700}
    {:ok, pid, trackerid} = Tracker.Torrent.add_peer(torrent_pid, test_data)

    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :downloads}, torrent_pid) == 0

    update =
      %{event: "completed",
        trackerid: trackerid,
        downloaded: 700,
        uploaded: 600,
        left: 0}
    Tracker.Peer.announce(pid, Map.merge(test_data, update))
    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :downloads}, torrent_pid) == 1
  end

  # peer stopping ------------------------------------------------------
  test "should decrement its incomplete statistics when an incomplete peer stops" do
    torrent_pid = Tracker.Torrent.create(@dummy_meta_info)
    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0

    test_data =
      %{info_hash: @info_hash,
        ip: {127, 0, 0, 1}, port: 31337,
        peer_id: "foo-bar-baz",
        event: "started",
        downloaded: 0,
        uploaded: 0,
        left: 700}
    {:ok, pid, trackerid} = Tracker.Torrent.add_peer(torrent_pid, test_data)

    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 1

    update =
      %{event: "stopped",
        trackerid: trackerid,
        downloaded: 700,
        uploaded: 600,
        left: 0}
    Tracker.Peer.announce(pid, Map.merge(test_data, update))
    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0
  end

  test "should decrement its complete statistics when a complete peer stops" do
    torrent_pid = Tracker.Torrent.create(@dummy_meta_info)
    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0
    assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 0

    test_data =
      %{info_hash: @info_hash,
        ip: {127, 0, 0, 1}, port: 31337,
        peer_id: "foo",
        event: "started",
        downloaded: 0,
        uploaded: 0,
        left: 700}
    {:ok, pid, trackerid} = Tracker.Torrent.add_peer(torrent_pid, test_data)

    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 1
    assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 0

    update =
      %{event: "completed",
        trackerid: trackerid,
        downloaded: 700,
        uploaded: 600,
        left: 0}
    Tracker.Peer.announce(pid, Map.merge(test_data, update))
    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0
    assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 1

    update =
      %{event: "stopped",
        trackerid: trackerid,
        downloaded: 700,
        uploaded: 600,
        left: 0}
    Tracker.Peer.announce(pid, Map.merge(test_data, update))

    :timer.sleep 10
    assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 0
    assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0
  end

  # peer dissapearing/timing out ---------------------------------------
  # test "should decrement its incomplete statistics when an incomplete peer times out"
  # test "should decrement its complete statistics when a complete peer times out"
end
