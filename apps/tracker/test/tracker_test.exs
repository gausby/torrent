defmodule TrackerTest do
  use ExUnit.Case
  use Plug.Test
  doctest Tracker

  defp call(mod, conn),
    do: mod.call(conn, [])

  test "getting announce" do
    conn = call(Tracker, conn(:get, "announce"))
    assert conn.resp_body == Bencode.encode("hello, world!")
  end
end
