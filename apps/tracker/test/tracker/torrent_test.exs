defmodule Tracker.TorrentTest do
  use ExUnit.Case
  # import TrackerTest.Helpers
  doctest Tracker.Torrent

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

  # Adding a new torrent ===============================================
  # test "should register a new torrent" do
  #   info_hash = "yyyyyyyyyyyyyyyyyyyy"
  #   pid = create_torrent(%{info_hash: info_hash})
  #   assert ^pid = :gproc.where({:n, :l, {Tracker.Torrent, info_hash}})
  # end

  # test "should return the same pid when registering the same info_hash twice (or more)" do
  #   data = %{info_hash: "xxxxxxxxxxxxxxxxxxxx", size: 1, name: "foo"}
  #   pid1 = Tracker.Torrent.create(data)
  #   pid2 = Tracker.Torrent.create(data)
  #   assert pid1 == pid2
  # end

  # test "should be able to track peers" do
  #   info_hash = "xxxxxxxxxxxxxxxxxxxx"
  #   torrent_pid = create_torrent(%{info_hash: info_hash})
  #   {:ok, pid, _} = create_peer(torrent_pid)
  #   assert [^pid] = Tracker.Torrent.list_all_peers(info_hash)
  # end

  # Removing a torrent =================================================
  # test "should remove all peers when shutting down on purpose" do
  #   info_hash = "xxxxxxxxxxxxxxxxxxxx"
  #   torrent_pid = create_torrent(%{info_hash: info_hash})

  #   for peer_id <- ["foo", "bar", "baz"],
  #     do: create_peer(torrent_pid, %{peer_id: peer_id})

  #   assert length(Tracker.Torrent.list_all_peers(info_hash)) == 3
  #   Tracker.Torrent.stop(torrent_pid)
  #   :timer.sleep 10
  #   assert Process.alive?(torrent_pid) == false
  #   assert length(Tracker.Torrent.list_all_peers(info_hash)) == 0
  # end

  # # Statistics =========================================================

  # # 'incomplete' peers downloading, "leeching"
  # # 'complete' peers marked as done, "seeders"
  # # 'downloads' completed downloads since beginning of time

  # # peer joining -------------------------------------------------------
  # test "should update incomplete statistics when a new peer joins" do
  #   torrent_pid = create_torrent()
  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0

  #   create_peer(torrent_pid)
  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 1
  # end

  # test "should not increment 'downloads' when a peer joins and announce 0 left" do
  #   torrent_pid = create_torrent()
  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :downloads}, torrent_pid) == 0

  #   create_peer(torrent_pid, %{left: 0})
  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :downloads}, torrent_pid) == 0
  # end

  # # peer completing ----------------------------------------------------
  # test "should increment its complete statistics and decrement its incomplete statistics when a peer complete" do
  #   torrent_pid = create_torrent()
  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 0
  #   assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0

  #   {:ok, pid, _trackerid} = create_peer(torrent_pid)

  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 1
  #   assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 0

  #   update = %{event: "completed", left: 0}
  #   Tracker.Peer.announce(pid, generate_announce_data(update))

  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0
  #   assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 1
  # end

  # test "should increment its downloads statistics when a peer complete" do
  #   torrent_pid = create_torrent()
  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :downloads}, torrent_pid) == 0

  #   {:ok, pid, trackerid} = create_peer(torrent_pid)

  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :downloads}, torrent_pid) == 0

  #   update =
  #     %{event: "completed",
  #       trackerid: trackerid,
  #       left: 0}
  #   Tracker.Peer.announce(pid, generate_announce_data(update))

  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :downloads}, torrent_pid) == 1
  # end

  # # peer stopping ------------------------------------------------------
  # test "should decrement its incomplete statistics when an incomplete peer stops" do
  #   torrent_pid = create_torrent()
  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0

  #   {:ok, pid, trackerid} = create_peer(torrent_pid)

  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 1

  #   update =
  #     %{event: "stopped", trackerid: trackerid}
  #   Tracker.Peer.announce(pid, generate_announce_data(update))

  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0
  # end

  # test "should decrement its complete statistics when a complete peer stops" do
  #   torrent_pid = create_torrent()
  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0
  #   assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 0

  #   {:ok, pid, trackerid} = create_peer(torrent_pid)

  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 1
  #   assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 0

  #   update =
  #     %{event: "completed",
  #       trackerid: trackerid,
  #       left: 0}
  #   Tracker.Peer.announce(pid, generate_announce_data(update))

  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0
  #   assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 1

  #   update =
  #     %{event: "stopped",
  #       trackerid: trackerid}
  #   Tracker.Peer.announce(pid, generate_announce_data(update))

  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 0
  #   assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 0
  # end

  # # Randomly killing a new torrent =====================================
  # test "when killed it should respawn and collect data from the peers" do
  #   torrent_pid = create_torrent(%{info_hash: "xxxxxxxxxxxxxxxxxxxx"})
  #   key = {:n, :l, {Tracker.Torrent, "xxxxxxxxxxxxxxxxxxxx"}}
  #   assert torrent_pid == :gproc.where(key)

  #   # spawn some peers
  #   peers = for peer_id <- ["foo", "bar"] do
  #     {:ok, pid, trackerid} =
  #       create_peer(torrent_pid, %{peer_id: peer_id})
  #     {pid, trackerid}
  #   end
  #   :timer.sleep 10

  #   # announce the first peer as complete
  #   [{first_pid, first_trackerid}|_] = peers
  #   update =
  #     %{event: "completed",
  #       trackerid: first_trackerid,
  #       downloaded: 700,
  #       uploaded: 600,
  #       left: 0}
  #   Tracker.Peer.announce(first_pid, generate_announce_data(update))
  #   :timer.sleep 10

  #   assert :gproc.get_value({:c, :l, :incomplete}, torrent_pid) == 1
  #   assert :gproc.get_value({:c, :l, :complete}, torrent_pid) == 1

  #   # kill the tracker
  #   Process.exit(torrent_pid, :kill)
  #   {respawned_pid, _} = :gproc.await(key, 2000)
  #   :timer.sleep 10
  #   assert :gproc.get_value({:c, :l, :incomplete}, respawned_pid) == 1
  #   assert :gproc.get_value({:c, :l, :complete}, respawned_pid) == 1
  # end

  # # peer dissapearing/timing out ---------------------------------------
  # # test "should decrement its incomplete statistics when an incomplete peer times out"
  # # test "should decrement its complete statistics when a complete peer times out"
end
