defmodule Tracker.UtilsTest do
  use ExUnit.Case
  doctest Tracker.Utils

  test "find the correct scrape url for annonuce" do
    assert {:ok, "/scrape"} = Tracker.Utils.to_scrape_path("/announce")
    assert {:ok, "/x/scrape"} = Tracker.Utils.to_scrape_path("/x/announce")
    assert {:ok, "/x/y/z/scrape"} = Tracker.Utils.to_scrape_path("/x/y/z/announce")

    assert {:ok, "/x/y/z/scrape.php"} = Tracker.Utils.to_scrape_path("/x/y/z/announce.php")
    assert {:ok, "/scrape?x2%0644"} = Tracker.Utils.to_scrape_path("/announce?x2%0644")

    assert {:error, _} = Tracker.Utils.to_scrape_path("/a")
    assert {:error, _} = Tracker.Utils.to_scrape_path("/announce?x=2/4")
    assert {:error, _} = Tracker.Utils.to_scrape_path("/x%064announce")
  end
end
