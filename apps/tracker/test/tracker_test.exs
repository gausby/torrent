defmodule TrackerTest do
  use ExUnit.Case
  doctest Tracker

  setup do
    {:ok, pid} = Tracker.start(:normal, [])
    on_exit(fn ->
      if (Process.alive?(pid)), do: Process.exit(pid, :normal)
      :timer.sleep 10
    end)
    :ok
  end

  test "tracking a new file" do
    info_hash = "xxxxxxxxxxxxxxxxxxxx"
    Tracker.add(info_hash)
    # adding a new file should spawn an info-, statistics-, and peer supervisor-process
    assert {_pid, _} = :gproc.await({:n, :l, {Tracker.File.Info, info_hash}}, 200)
    assert {_pid, _} = :gproc.await({:n, :l, {Tracker.File.Statistics, info_hash}}, 200)
    assert {_pid, _} = :gproc.await({:n, :l, {Tracker.File.Peers, info_hash}}, 200)
  end

  test "should return the same pid when registering the same info_hash twice (or more)" do
    info_hash = "xxxxxxxxxxxxxxxxxxxx"
    Tracker.add(info_hash)
    {pid, _} = :gproc.await({:n, :l, {Tracker.File, info_hash}}, 200)
    assert {:ok, ^pid} = Tracker.add(info_hash)
  end

  test "creating a peer should return the trackerid" do
    info_hash = "yyyyyyyyyyyyyyyyyyyy"
    Tracker.add(info_hash)
    :gproc.await({:n, :l, {Tracker.File.Peers, info_hash}}, 200)

    {:ok, pid, trackerid} = Tracker.File.Peers.add(info_hash)
    assert {^pid, _} = :gproc.await({:n, :l, {Tracker.File.Peer, {info_hash, trackerid}}}, 200)
  end

  test "creating multiple peers should different trackerids" do
    info_hash = "yyyyyyyyyyyyyyyyyyyy"
    Tracker.add(info_hash)
    :gproc.await({:n, :l, {Tracker.File.Peers, info_hash}}, 200)

    {:ok, _pid, trackerid} = Tracker.File.Peers.add(info_hash)
    {:ok, _pid, trackerid2} = Tracker.File.Peers.add(info_hash)
    refute trackerid == trackerid2
  end

  # Removing a torrent =================================================
  test "should remove all peers when shutting down on purpose" do
    info_hash = "01234567890123456789"
    Tracker.add(info_hash)
    {file_pid, _} = :gproc.await({:n, :l, {Tracker.File, info_hash}}, 200)

    {:ok, _pid, trackerid} = Tracker.File.Peers.add(info_hash)
    {:ok, _pid, trackerid2} = Tracker.File.Peers.add(info_hash)

    {peer_pid1, _} = :gproc.await({:n, :l, {Tracker.File.Peer, {info_hash, trackerid}}})
    {peer_pid2, _} = :gproc.await({:n, :l, {Tracker.File.Peer, {info_hash, trackerid2}}})

    assert Process.alive?(file_pid)
    assert Process.alive?(peer_pid1)
    assert Process.alive?(peer_pid2)

    Tracker.remove(info_hash)

    refute Process.alive?(file_pid)
    refute Process.alive?(peer_pid1)
    refute Process.alive?(peer_pid2)
  end

  # Statistics =========================================================
  test "statistics on a tracked file" do
    info_hash = "23456789012345678901"
    Tracker.add(info_hash)
    :gproc.await({:n, :l, {Tracker.File, info_hash}}, 200)
    expected = %Tracker.File.Statistics{downloaded: 0, incomplete: 0, complete: 0}
    assert expected == Tracker.File.Statistics.get(info_hash)
  end

  # peer joining -------------------------------------------------------

  test "should update incomplete statistics when a new peer joins" do
    info_hash = "12345678901234567890"
    Tracker.add(info_hash)
    :gproc.await({:n, :l, {Tracker.File, info_hash}}, 200)
    {:ok, _, trackerid} = Tracker.File.Peers.add(info_hash)
    announce_data =
      %{"event" => "started"}
    Tracker.File.Peer.Announce.announce(info_hash, trackerid, announce_data)
    expected = %Tracker.File.Statistics{downloaded: 0, incomplete: 1, complete: 0}
    assert expected == Tracker.File.Statistics.get(info_hash)
  end
  # test "should not increment 'downloads' when a peer joins and announce 0 left"

  # peer completing ----------------------------------------------------
  test "increment complete and download, and decrement incomplete statistics when a peer complete" do
    info_hash = "12345678901234567890"
    Tracker.add(info_hash)
    :gproc.await({:n, :l, {Tracker.File, info_hash}}, 200)
    {:ok, _, trackerid} = Tracker.File.Peers.add(info_hash)
    announce_data =
      %{"event" => "started", "left" => 1, "downloaded" => 1, "uploaded" => 1}
    Tracker.File.Peer.Announce.announce(info_hash, trackerid, announce_data)

    announce_data =
      %{"event" => "completed", "left" => 1, "downloaded" => 1, "uploaded" => 1}

    Tracker.File.Peer.Announce.announce(info_hash, trackerid, announce_data)
    expected = %Tracker.File.Statistics{incomplete: 0, complete: 1, downloaded: 1}
    assert expected == Tracker.File.Statistics.get(info_hash)
  end

  # peer stopping ------------------------------------------------------
  test "should decrement its incomplete statistics when an incomplete peer stops" do
    info_hash = "12345678901234567890"
    Tracker.add(info_hash)
    :gproc.await({:n, :l, {Tracker.File, info_hash}}, 200)
    {:ok, _, trackerid} = Tracker.File.Peers.add(info_hash)
    announce_data =
      %{"event" => "started"}
    Tracker.File.Peer.Announce.announce(info_hash, trackerid, announce_data)

    announce_data =
      %{"event" => "stopped"}
    Tracker.File.Peer.Announce.announce(info_hash, trackerid, announce_data)

    expected = %Tracker.File.Statistics{incomplete: 0, complete: 0, downloaded: 0}
    assert expected == Tracker.File.Statistics.get(info_hash)
  end

  test "should decrement its complete statistics when a complete peer stops" do
    info_hash = "12345678901234567890"
    Tracker.add(info_hash)
    :gproc.await({:n, :l, {Tracker.File, info_hash}}, 200)
    {:ok, _, trackerid} = Tracker.File.Peers.add(info_hash)

    Tracker.File.Peer.Announce.announce(info_hash, trackerid, %{"event" => "started"})
    Tracker.File.Peer.Announce.announce(info_hash, trackerid, %{"event" => "completed"})
    Tracker.File.Peer.Announce.announce(info_hash, trackerid, %{"event" => "stopped"})

    expected = %Tracker.File.Statistics{incomplete: 0, complete: 0, downloaded: 1}
    assert expected == Tracker.File.Statistics.get(info_hash)
  end

  # Randomly killing a new torrent =====================================
  # test "when killed it should respawn and collect data from the peers"

  # peer dissapearing/timing out ---------------------------------------
  # test "should decrement its incomplete statistics when an incomplete peer times out"
  # test "should decrement its complete statistics when a complete peer times out"

  test "state should store uploaded/downloaded/left" do
    info_hash = "xxxxxxxxxxxxxxxxxxxx"
    trackerid = "yyyyyyyyyyyyyyyyyyyy"
    opts = [info_hash: info_hash, trackerid: trackerid]

    Tracker.File.Peer.State.start_link(opts)
    update_data = %{"uploaded" => "10", "left" => "200", "downloaded" => "39"}
    assert Tracker.File.Peer.State.update(info_hash, trackerid, update_data) == :ok
    expected = %Tracker.File.Peer.State{uploaded: "10", left: "200", downloaded: "39"}
    assert Tracker.File.Peer.State.get(info_hash, trackerid) == expected
  end

end
