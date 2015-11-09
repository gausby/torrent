ExUnit.start()

defmodule TrackerTest.Request do
  @moduledoc """
  This module is used to ensure the test data, send to the tracker
  implementation follows the conventions for an announce.
  """
  defstruct info_hash: nil,
            peer_id: "xxxxxxxxxxxxxxxxxxxx",
            port: 31337, # typically 6881..6889
            uploaded: 0,
            downloaded: 0,
            left: 700,
            compact: nil, # 1 or 0
            no_peer_id: nil, # ignored if compact is enabled
            event: nil, # started, stopped, completed
            # optional
            ip: nil, # will default to the clients ip
            numwant: nil,
            key: nil,
            trackerid: nil # should be set on second announce

  def create() do
    %__MODULE__{}
  end

end

defmodule TrackerTest.Helpers do
  @info_hash "xxxxxxxxxxxxxxxxxxxx"
  @dummy_meta_info %{info_hash: "xxxxxxxxxxxxxxxxxxxx", size: 100, name: "test"}

  def create_torrent(data \\ %{}) do
    torrent = Map.merge(@dummy_meta_info, data)
    Tracker.Torrent.create(torrent)
    {tracker_pid, _} = :gproc.await({:n, :l, {Tracker.Torrent, torrent[:info_hash]}}, 2000)

    tracker_pid
  end

  def create_peer(torrent_pid, data \\ %{}) do
    test_data =
      %{info_hash: @info_hash,
        ip: {127, 0, 0, 1}, port: 31337,
        peer_id: "foo",
        event: "started",
        downloaded: 0,
        uploaded: 0,
        left: 700}

    Tracker.Torrent.add_peer(torrent_pid, Map.merge(test_data, data))
  end
end
