defmodule Tracker.PlugTest do
  use ExUnit.Case
  use Plug.Test
  # import TrackerTest.Helpers
  doctest Tracker.Plug

  alias TrackerTest.Request
  alias Tracker.File.Statistics

  defmodule TestTracker do
    use Plug.Router
    plug Tracker.Plug, path: "/announce"
    plug :match
    plug :dispatch

    match _ do
      send_resp conn, 404, "file not found"
    end
  end

  setup_all do
    :ok = Logger.remove_backend(:console)
    on_exit(fn -> Logger.add_backend(:console, flush: true) end)
    :ok
  end

  setup do
    {:ok, pid} = Tracker.start(:normal, [])
    on_exit(fn ->
      if (Process.alive?(pid)), do: Process.exit(pid, :normal)
      :timer.sleep 10
    end)
    :ok
  end

  # Announce ===========================================================
  test "announce should return an empty list when asking for zero peers" do
    Tracker.File.create("aaaaaaaaaaaaaaaaaaaa")

    request =
      %Request{
        event: "started",
        numwant: 0,
        port: 31337,
        info_hash: "aaaaaaaaaaaaaaaaaaaa"
      }
      |> Map.from_struct
      |> Map.delete(:trackerid)
      |> Map.delete(:ip)

    conn = conn(:get, "/announce", request) |> TestTracker.call([])
    response = Bencode.decode(conn.resp_body)

    refute response["failure_reason"]
    assert response["peers"] == []
  end

  test "announce should return an interval" do
    Tracker.File.create("aaaaaaaaaaaaaaaaaaaa")
    request =
      %Request{
        event: "started",
        numwant: 0,
        port: 31337,
        info_hash: "aaaaaaaaaaaaaaaaaaaa"
      }
      |> Map.from_struct
      |> Map.delete(:trackerid)
      |> Map.delete(:ip)

    conn = conn(:get, "/announce", request) |> TestTracker.call([])
    response = Bencode.decode(conn.resp_body)

    refute response["failure_reason"]
    assert is_number(response["interval"])
  end

  test "announce should return an error if event is started and a trackerid is set" do
    Tracker.File.create("aaaaaaaaaaaaaaaaaaaa")
    request =
      %Request{
        event: "started",
        trackerid: "hello",
        numwant: 0,
        port: 31337,
        info_hash: "aaaaaaaaaaaaaaaaaaaa"
      }
      |> Map.from_struct

    conn = conn(:get, "/announce", request) |> TestTracker.call([])
    response = Bencode.decode(conn.resp_body)

    assert response["failure_reason"]
    refute response["peers"] == []
  end

  # test "announce should be able to stop tracking a given peer" do
  #   info_hash = "aaaaaaaaaaaaaaaaaaaa"
  #   Tracker.File.create(info_hash)
  #   request =
  #     %Request{
  #       event: "started",
  #       numwant: 0,
  #       port: 31337,
  #       info_hash: info_hash}
  #     |> Map.from_struct
  #   conn = conn(:get, "/announce", request) |> TestTracker.call([])
  #   response = Bencode.decode(conn.resp_body)

  #   refute response["failure_reason"]
  #   assert response["trackerid"]
  #   # should have one peer by now
  #   assert Tracker.File.Peers.count(info_hash) == 1

  #   request = %{request | event: "stopped", trackerid: response["trackerid"]}
  #   conn = conn(:get, "/announce", request) |> TestTracker.call([])
  #   response = Bencode.decode(conn.resp_body)

  #   refute response["failure_reason"]
  #   # should have no peers by now
  #   # todo, implement removal of peers
  #   assert Tracker.File.Peers.count(info_hash) == 0
  # end

  test "announce should be able to complete a given peer" do
    info_hash = "aaaaaaaaaaaaaaaaaaaa"
    Tracker.File.create(info_hash)
    request =
      %Request{
        event: "started",
        numwant: 0,
        port: 31337,
        ip: {127, 0, 0, 1},
        info_hash: info_hash}
      |> Map.from_struct
    conn = conn(:get, "/announce", request) |> TestTracker.call([])
    response = Bencode.decode(conn.resp_body)

    # at this point the peer is incomplete
    assert Statistics.get(info_hash) == %Statistics{downloaded: 0, complete: 0, incomplete: 1}
    # announce the peer complete
    request = %{request | downloaded: 700, event: "completed", trackerid: response["trackerid"]}
    conn(:get, "/announce", request) |> TestTracker.call([])

    assert Statistics.get(info_hash) == %Statistics{downloaded: 1, complete: 1, incomplete: 0}
  end

  test "announce should be able to announce without an event" do
    info_hash = "aaaaaaaaaaaaaaaaaaaa"
    Tracker.File.create(info_hash)
    # start peer
    request =
      %Request{
        event: "started",
        numwant: 0,
        port: 31337,
        info_hash: info_hash}
      |> Map.from_struct
    conn = conn(:get, "/announce", request) |> TestTracker.call([])
    response = Bencode.decode(conn.resp_body)

    refute response["failure_reason"]
    assert response["trackerid"]

    request = %{request | downloaded: 700, trackerid: response["trackerid"]} |> Map.delete(:event)
    conn = conn(:get, "/announce", request) |> TestTracker.call([])
    response = Bencode.decode(conn.resp_body)
    refute response["failure_reason"]
  end

  test "announce should return an error if event is set but no trackerid is given" do
    Tracker.File.create("aaaaaaaaaaaaaaaaaaaa")
    # start peer
    request =
      %Request{
        event: "started",
        numwant: 0,
        port: 31337,
        info_hash: "aaaaaaaaaaaaaaaaaaaa"}
      |> Map.from_struct
    conn = conn(:get, "/announce", request) |> TestTracker.call([])
    response = Bencode.decode(conn.resp_body)
    refute response["failure_reason"]
    assert response["trackerid"]

    # make a new request, but do not specify a trackerid
    request = %{request | event: "completed", downloaded: 700}
    conn = conn(:get, "/announce", request) |> TestTracker.call([])
    response = Bencode.decode(conn.resp_body)
    assert response["failure_reason"]
  end

  test "announce should return a list of peers" do
    info_hash = "aaaaaaaaaaaaaaaaaaaa"
    peer_id = "foo_bar"
    {:ok, _pid} = Tracker.File.create(info_hash)
    # spawn some peers
    {:ok, _pid, trackerid} = Tracker.File.Peers.add(info_hash)
    announce_data =
      %{"event" => "started",
        "numwant" => 0,
        "ip" => {127, 0, 0, 1}, "port" => 12341,
        "peer_id" => peer_id, "info_hash" => info_hash,
        "trackerid" => trackerid
       }
    Tracker.File.Peer.Announce.announce(info_hash, trackerid, announce_data)
    # start peer
    request =
      %Request{
        event: "started",
        numwant: 35,
        port: 31337,
        info_hash: info_hash}
      |> Map.from_struct
    conn = conn(:get, "/announce", request) |> TestTracker.call([])
    response = Bencode.decode(conn.resp_body)
    refute response["failure_reason"]
    expected =
      %{"peer_id" => peer_id,
        "ip" => "127.0.0.1",
        "port" => 12341}
    assert response["peers"] == [expected]
  end

  test "announce should return a list of peers in compact format if requested as such" do
    info_hash = "aaaaaaaaaaaaaaaaaaaa"
    Tracker.File.create(info_hash)
    {:ok, _pid, trackerid} = Tracker.File.Peers.add(info_hash)
    # spawn some peers
    announce_data =
      %{"event" => "started",
        "numwant" => 0,
        "ip" => {127, 0, 0, 1}, "port" => 12341,
        "peer_id" => "foo", "info_hash" => info_hash,
        "trackerid" => trackerid
       }
    Tracker.File.Peer.Announce.announce(info_hash, trackerid, announce_data)
    # start peer
    request =
      %Request{
        event: "started",
        numwant: 35,
        port: 31337,
        info_hash: info_hash,
        compact: 1}
      |> Map.from_struct
    conn = conn(:get, "/announce", request) |> TestTracker.call([])
    response = Bencode.decode(conn.resp_body)
    refute response["failure_reason"]
    assert response["peers"] == <<127, 0, 0, 1, 48, 53>>
  end

  test "announce should statistics for the given torrent" do
    info_hash = "aaaaaaaaaaaaaaaaaaaa"
    Tracker.File.create(info_hash)
    {:ok, _pid, trackerid} = Tracker.File.Peers.add(info_hash)
    # spawn some peers
    announce_data =
      %{"event" => "started",
        "numwant" => 0,
        "ip" => {127, 0, 0, 1}, "port" => 12341,
        "peer_id" => "foo", "info_hash" => info_hash,
        "trackerid" => trackerid
       }
    Tracker.File.Peer.Announce.announce(info_hash, trackerid, announce_data)
    # start and announce peer
    request =
      %Request{
        event: "started",
        numwant: 35,
        port: 12342,
        info_hash: info_hash}
      |> Map.from_struct
    conn = conn(:get, "/announce", request) |> TestTracker.call([])
    response = Bencode.decode(conn.resp_body)
    assert response["incomplete"] == 2
    assert response["complete"] == 0
  end

  # scrape =============================================================
  test "should be able to scrape" do
    info_hashes = ["aaaaaaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbbbbbb", "cccccccccccccccccccc"]
    result = for info_hash <- info_hashes, into: %{} do
      Tracker.File.create(info_hash)
      {info_hash, %{complete: 0, downloaded: 0, incomplete: 0}}
    end
    conn = conn(:get, "/scrape") |> TestTracker.call([])
    assert conn.resp_body == Bencode.encode(%{files: result})
  end

  test "should return an empty list when scraping a tracker that track no files" do
    conn = conn(:get, "/scrape") |> TestTracker.call([])
    assert conn.resp_body == Bencode.encode(%{files: %{}})
  end

  test "should return an empty list when scraping and specifying a torrent that does not exist" do
    conn = conn(:get, "/scrape?info_hash=aaaaaaaaaaaaaaaaaaaa") |> TestTracker.call([])
    assert conn.resp_body == Bencode.encode(%{files: %{}})
  end

  test "should be able to specify the info_hash of interest when scraping" do
    info_hashes = ["aaaaaaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbbbbbb", "cccccccccccccccccccc"]
    result = for info_hash <- info_hashes, into: %{} do
      Tracker.File.create(info_hash)
      {info_hash, %{complete: 0, downloaded: 0, incomplete: 0}}
    end
    conn = conn(:get, "/scrape?info_hash=bbbbbbbbbbbbbbbbbbbb") |> TestTracker.call([])

    assert conn.resp_body == Bencode.encode(%{files: %{bbbbbbbbbbbbbbbbbbbb: result["bbbbbbbbbbbbbbbbbbbb"]}})
  end

  test "should be able to specify multiple info_hashes of interest when scraping" do
    info_hashes = ["aaaaaaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbbbbbb", "cccccccccccccccccccc"]
    result = for info_hash <- info_hashes, into: %{} do
      Tracker.File.create(info_hash)
      {info_hash, %{complete: 0, downloaded: 0, incomplete: 0}}
    end
    conn = conn(:get, "/scrape?info_hash=bbbbbbbbbbbbbbbbbbbb&info_hash=cccccccccccccccccccc") |> TestTracker.call([])
    expected_result =
      Bencode.encode(
        %{files: %{
             bbbbbbbbbbbbbbbbbbbb: result["bbbbbbbbbbbbbbbbbbbb"],
             cccccccccccccccccccc: result["cccccccccccccccccccc"]}})

    assert conn.resp_body == expected_result
  end
end
