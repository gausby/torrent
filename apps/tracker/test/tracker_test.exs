defmodule TrackerTest do
  use ExUnit.Case
  use Plug.Test
  doctest Tracker

  defmodule TestTracker do
    use Plug.Router
    plug Tracker, path: "/announce"
    plug :match
    plug :dispatch

    match _ do
      send_resp conn, 404, "file not found"
    end
  end

  # dummy data for now!

  test "getting announce" do
    conn = conn(:get, "/announce") |> TestTracker.call([])
    assert conn.resp_body == Bencode.encode("hello, world!")
  end

  test "should be able to scrape" do
    conn = conn(:get, "/scrape") |> TestTracker.call([])
    assert conn.resp_body == Bencode.encode("all")
  end

  test "should be able to specify the info_hash of interest when scraping" do
    conn = conn(:get, "/scrape?info_hash=aaaaaaaaaaaaaaaaaaaa") |> TestTracker.call([])
    assert conn.resp_body == Bencode.encode(["aaaaaaaaaaaaaaaaaaaa"])
  end

  test "should be able to specify multiple info_hashes of interest when scraping" do
    conn = conn(:get, "/scrape?info_hash=aaaaaaaaaaaaaaaaaaaa&info_hash=bbbbbbbbbbbbbbbbbbbb&info_hash=cccccccccccccccccccc") |> TestTracker.call([])
    assert conn.resp_body == Bencode.encode(["aaaaaaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbbbbbb", "cccccccccccccccccccc"])
  end
end
