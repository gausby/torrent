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
    # for now we just assume empty list
    assert conn.resp_body == Bencode.encode(%{files: []})
  end

  test "should be able to specify the info_hash of interest when scraping" do
    conn = conn(:get, "/scrape?info_hash=aaaaaaaaaaaaaaaaaaaa") |> TestTracker.call([])
    assert conn.resp_body == "d5:filesd20:aaaaaaaaaaaaaaaaaaaad8:completei0e10:downloadedi0e10:incompletei0eeee"
  end

  test "should be able to specify multiple info_hashes of interest when scraping" do
    info_hashes = ["aaaaaaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbbbbbb", "cccccccccccccccccccc"]
    conn = conn(:get, "/scrape?info_hash=#{Enum.join(info_hashes, "&info_hash=")}") |> TestTracker.call([])
    assert conn.resp_body == "d5:filesd20:aaaaaaaaaaaaaaaaaaaad8:completei0e10:downloadedi0e10:incompletei0ee20:bbbbbbbbbbbbbbbbbbbbd8:completei0e10:downloadedi0e10:incompletei0ee20:ccccccccccccccccccccd8:completei0e10:downloadedi0e10:incompletei0eeee"
  end
end
