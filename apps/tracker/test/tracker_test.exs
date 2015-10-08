defmodule TrackerTest do
  use ExUnit.Case
  use Plug.Test
  doctest Tracker

  defp call(mod, conn),
    do: mod.call(conn, [])

  # dummy data for now!

  test "getting announce" do
    conn = call(Tracker, conn(:get, "announce"))
    assert conn.resp_body == Bencode.encode("hello, world!")
  end

  test "should be able to scrape" do
    conn = call(Tracker, conn(:get, "scrape"))
    assert conn.resp_body == Bencode.encode("all")
  end

  test "should be able to specify the info_hash of interest when scraping" do
    conn = call(Tracker, conn(:get, "scrape?info_hash=aaaaaaaaaaaaaaaaaaaa"))
    assert conn.resp_body == Bencode.encode(["aaaaaaaaaaaaaaaaaaaa"])
  end

  test "should be able to specify multiple info_hashes of interest when scraping" do
    conn = call(Tracker, conn(:get, "scrape?info_hash=aaaaaaaaaaaaaaaaaaaa&info_hash=bbbbbbbbbbbbbbbbbbbb&info_hash=cccccccccccccccccccc"))
    assert conn.resp_body == Bencode.encode(["aaaaaaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbbbbbb", "cccccccccccccccccccc"])
  end
end
