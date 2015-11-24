defmodule Tracker.PlugTest do
  use ExUnit.Case
  use Plug.Test
  # import TrackerTest.Helpers
  doctest Tracker.Plug
  alias TrackerTest.Request

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
    Tracker.add("aaaaaaaaaaaaaaaaaaaa")

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
    Tracker.add("aaaaaaaaaaaaaaaaaaaa")
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
    Tracker.add("aaaaaaaaaaaaaaaaaaaa")
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
  #   Tracker.Torrent.create(%{info_hash: "aaaaaaaaaaaaaaaaaaaa", size: 700, name: "foo bar"})
  #   request =
  #     %Request{
  #       event: "started",
  #       numwant: 0,
  #       port: 31337,
  #       info_hash: "aaaaaaaaaaaaaaaaaaaa"}
  #     |> Map.from_struct
  #   conn = conn(:get, "/announce", request) |> TestTracker.call([])
  #   response = Bencode.decode(conn.resp_body)

  #   refute response["failure_reason"]
  #   assert response["trackerid"]
  #   # should have one peer by now
  #   assert length(Tracker.Torrent.list_all_peers("aaaaaaaaaaaaaaaaaaaa")) == 1

  #   request = %{request | event: "stopped", trackerid: response["trackerid"]}
  #   conn = conn(:get, "/announce", request) |> TestTracker.call([])
  #   response = Bencode.decode(conn.resp_body)

  #   refute response["failure_reason"]
  #   # should have no peers by now
  #   :timer.sleep 10
  #   assert length(Tracker.Torrent.list_all_peers("aaaaaaaaaaaaaaaaaaaa")) == 0
  # end

  # test "announce should be able to complete a given peer" do
  #   pid = Tracker.Torrent.create(%{info_hash: "aaaaaaaaaaaaaaaaaaaa", size: 700, name: "foo bar"})
  #   request =
  #     %Request{
  #       event: "started",
  #       numwant: 0,
  #       port: 31337,
  #       info_hash: "aaaaaaaaaaaaaaaaaaaa"}
  #     |> Map.from_struct
  #   conn = conn(:get, "/announce", request) |> TestTracker.call([])
  #   response = Bencode.decode(conn.resp_body)

  #   refute response["failure_reason"]
  #   assert response["trackerid"]
  #   # should have one incomplete and zero complete by now
  #   assert :gproc.get_value({:c, :l, :incomplete}, pid) == 1
  #   assert :gproc.get_value({:c, :l, :complete}, pid) == 0

  #   request = %{request | downloaded: 700, event: "completed", trackerid: response["trackerid"]}
  #   conn = conn(:get, "/announce", request) |> TestTracker.call([])
  #   response = Bencode.decode(conn.resp_body)

  #   refute response["failure_reason"]
  #   :timer.sleep 10
  #   # should have one complete and zero incomplete by now
  #   assert :gproc.get_value({:c, :l, :incomplete}, pid) == 0
  #   assert :gproc.get_value({:c, :l, :complete}, pid) == 1
  # end

  # test "announce should be able to announce without an event" do
  #   Tracker.Torrent.create(%{info_hash: "aaaaaaaaaaaaaaaaaaaa", size: 700, name: "foo bar"})
  #   # start peer
  #   request =
  #     %Request{
  #       event: "started",
  #       numwant: 0,
  #       port: 31337,
  #       info_hash: "aaaaaaaaaaaaaaaaaaaa"}
  #     |> Map.from_struct
  #   conn = conn(:get, "/announce", request) |> TestTracker.call([])
  #   response = Bencode.decode(conn.resp_body)

  #   refute response["failure_reason"]
  #   assert response["trackerid"]

  #   request = %{request | downloaded: 700, trackerid: response["trackerid"]} |> Map.delete(:event)
  #   conn = conn(:get, "/announce", request) |> TestTracker.call([])
  #   response = Bencode.decode(conn.resp_body)
  #   refute response["failure_reason"]
  # end

  # test "announce should return an error if event is set but no trackerid is given" do
  #   Tracker.Torrent.create(%{info_hash: "aaaaaaaaaaaaaaaaaaaa", size: 700, name: "foo bar"})
  #   # start peer
  #   request =
  #     %Request{
  #       event: "started",
  #       numwant: 0,
  #       port: 31337,
  #       info_hash: "aaaaaaaaaaaaaaaaaaaa"}
  #     |> Map.from_struct
  #   conn = conn(:get, "/announce", request) |> TestTracker.call([])
  #   response = Bencode.decode(conn.resp_body)
  #   refute response["failure_reason"]
  #   assert response["trackerid"]

  #   # make a new request, but do not specify a trackerid
  #   request = %{request | event: "completed", downloaded: 700}
  #   conn = conn(:get, "/announce", request) |> TestTracker.call([])
  #   response = Bencode.decode(conn.resp_body)
  #   assert response["failure_reason"]
  # end

  # test "announce should return a list of peers" do
  #   info_hash = "aaaaaaaaaaaaaaaaaaaa"
  #   torrent_pid = create_torrent(%{info_hash: info_hash, size: 700, name: "foo bar"})
  #   # spawn some peers
  #   for {peer_id, port} <- [{"bar", 12341}] do
  #     peer_data =
  #       %{info_hash: info_hash,
  #         peer_id: peer_id,
  #         port: port}
  #     create_peer(torrent_pid, peer_data)
  #   end
  #   :timer.sleep 10
  #   # start peer
  #   request =
  #     %Request{
  #       event: "started",
  #       numwant: 35,
  #       port: 31337,
  #       info_hash: info_hash}
  #     |> Map.from_struct
  #   conn = conn(:get, "/announce", request) |> TestTracker.call([])
  #   response = Bencode.decode(conn.resp_body)
  #   refute response["failure_reason"]
  #   expected =
  #     %{"peer_id" => "bar",
  #       "ip" => "127.0.0.1",
  #       "port" => 12341}
  #   assert response["peers"] == [expected]
  # end

  # test "announce should return a list of peers in compact format if requested as such" do
  #   info_hash = "aaaaaaaaaaaaaaaaaaaa"
  #   torrent_pid = create_torrent(%{info_hash: info_hash, size: 700, name: "foo bar"})
  #   # spawn some peers
  #   for {peer_id, port} <- [{"bar", 12341}] do
  #     peer_data =
  #       %{info_hash: info_hash,
  #         peer_id: peer_id,
  #         port: port}
  #     create_peer(torrent_pid, peer_data)
  #   end
  #   :timer.sleep 10
  #   # start peer
  #   request =
  #     %Request{
  #       event: "started",
  #       numwant: 35,
  #       port: 31337,
  #       info_hash: info_hash,
  #       compact: 1}
  #     |> Map.from_struct
  #   conn = conn(:get, "/announce", request) |> TestTracker.call([])
  #   response = Bencode.decode(conn.resp_body)
  #   refute response["failure_reason"]
  #   assert response["peers"] == <<127, 0, 0, 1, 48, 53>>
  # end

  # test "announce should statistics for the given torrent" do
  #   info_hash = "aaaaaaaaaaaaaaaaaaaa"
  #   torrent_pid = create_torrent(%{info_hash: info_hash, size: 700, name: "foo bar"})
  #   # spawn some peers
  #   for {peer_id, port} <- [{"bar", 12341}] do
  #     peer_data =
  #       %{info_hash: info_hash,
  #         peer_id: peer_id,
  #         port: port}
  #     create_peer(torrent_pid, peer_data)
  #   end
  #   :timer.sleep 10
  #   # start and announce peer
  #   request =
  #     %Request{
  #       event: "started",
  #       numwant: 35,
  #       port: 31337,
  #       info_hash: info_hash}
  #     |> Map.from_struct
  #   conn = conn(:get, "/announce", request) |> TestTracker.call([])
  #   response = Bencode.decode(conn.resp_body)

  #   assert response["incomplete"] == 2
  #   assert response["complete"] == 0
  # end

  # # scrape =============================================================
  # test "should be able to scrape" do
  #   info_hashes = ["aaaaaaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbbbbbb", "cccccccccccccccccccc"]
  #   result = for info_hash <- info_hashes, into: %{} do
  #     Tracker.Torrent.create(%{info_hash: info_hash, size: 1, name: info_hash})
  #     {info_hash, %{complete: 0, downloads: 0, incomplete: 0}}
  #   end
  #   :timer.sleep 10
  #   conn = conn(:get, "/scrape") |> TestTracker.call([])

  #   assert conn.resp_body == Bencode.encode(%{files: result})
  # end

  # test "should return an empty list when scraping a tracker that track no torrents" do
  #   conn = conn(:get, "/scrape") |> TestTracker.call([])
  #   assert conn.resp_body == Bencode.encode(%{files: %{}})
  # end

  # test "should return an empty list when scraping and specifying a torrent that does not exist" do
  #   conn = conn(:get, "/scrape?info_hash=aaaaaaaaaaaaaaaaaaaa") |> TestTracker.call([])
  #   assert conn.resp_body == Bencode.encode(%{files: %{}})
  # end

  # test "should be able to specify the info_hash of interest when scraping" do
  #   info_hashes = ["aaaaaaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbbbbbb", "cccccccccccccccccccc"]
  #   result = for info_hash <- info_hashes, into: %{} do
  #     Tracker.Torrent.create(%{info_hash: info_hash, size: 1, name: info_hash})
  #     {info_hash, %{complete: 0, downloads: 0, incomplete: 0}}
  #   end
  #   :timer.sleep 10
  #   conn = conn(:get, "/scrape?info_hash=bbbbbbbbbbbbbbbbbbbb") |> TestTracker.call([])

  #   assert conn.resp_body == Bencode.encode(%{files: %{bbbbbbbbbbbbbbbbbbbb: result["bbbbbbbbbbbbbbbbbbbb"]}})
  # end

  # test "should be able to specify multiple info_hashes of interest when scraping" do
  #   info_hashes = ["aaaaaaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbbbbbb", "cccccccccccccccccccc"]
  #   result = for info_hash <- info_hashes, into: %{} do
  #     Tracker.Torrent.create(%{info_hash: info_hash, size: 1, name: info_hash})
  #     {info_hash, %{complete: 0, downloads: 0, incomplete: 0}}
  #   end
  #   :timer.sleep 10
  #   conn = conn(:get, "/scrape?info_hash=bbbbbbbbbbbbbbbbbbbb&info_hash=cccccccccccccccccccc") |> TestTracker.call([])

  #   expected_result =
  #     Bencode.encode(
  #       %{files: %{
  #            bbbbbbbbbbbbbbbbbbbb: result["bbbbbbbbbbbbbbbbbbbb"],
  #            cccccccccccccccccccc: result["cccccccccccccccccccc"]}})

  #   assert conn.resp_body == expected_result
  # end
end
